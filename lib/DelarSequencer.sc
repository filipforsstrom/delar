DelarSequencer {

	// initial variables
	var <server;
	var <targetNode;
	var <addAction;
	var <doneLoadingCallback;

	// sample data
	var sample;

	var synth;

	// osc
	var osc;

	// other state
	var <routine;
	var <currentStep;
	var numOfSlices;
	var slice;
	var shortestFrameDuration;

	// settable values
	var <>playbackRate;
	var <>startPosition;
	var <>endPosition;
	var <>length;
	var <>slices;
	var <>activeSlices;
	var <>stepCallback;
	var <>attack;
	var <>release;
	var <>randFreq;
	var <>randLengthAmount;
	var <>randLengthUnquantized;
	var <>randPanAmount;
	var <>level;

	*new { arg server, targetNode, addAction, doneLoadingCallback;
		^super.newCopyArgs(server, targetNode, addAction, doneLoadingCallback).init
	}

	init {
		if (targetNode.isNil, { targetNode = server; });
		if (addAction.isNil, { addAction = \addToHead });
		/*Routine {
			var buf;
			buf = Buffer.read(server, path);
			server.sync;
			sample = buf;

			if(doneLoadingCallback.notNil, { doneLoadingCallback.value });
		}.play;*/

		SynthDef.new(\SampleSliceSequencer_1shot_env_raw_mono, {
			var buf = \buffer.ir;
			var rand = LFNoise1.kr(\randFreq.ir(0.5));
			var rate = \rate.ir;
			var duration = \duration.ir;
			var attack = \attack.ir(0.01).min(duration);
			var release = \release.ir(0.01).min(duration - attack);
			var sustain = (duration - (attack + release)).max(0);
			var env = EnvGen.ar(Env.new([0, 1, 1, 0], [attack, sustain, release]), doneAction:2);
			var phase = Phasor.ar(0, rate, \startFrame.ir, \endFrame.ir);
			var snd = BufRd.ar(1, buf, phase);
			snd = snd * env;
			snd = Pan2.ar(snd, rand * \randPanAmount.kr(0));
			Out.ar(\out.kr(0), (snd * \level.kr(0.5)).dup);
		}).send(server);

		SynthDef.new(\SampleSliceSequencer_1shot_env_raw_stereo, {
			var buf = \buffer.ir;
			var rand = LFNoise1.kr(\randFreq.ir(0.5));
			var rate = \rate.ir.max(0.25);
			var duration = \duration.ir;
			var attack = \attack.ir(0.01).max(0.01).min(duration);
			var release = \release.ir(0.01).max(0.01).min(duration - attack);
			var sustain = (duration - (attack + release)).max(0);
			var env = EnvGen.ar(Env.new([0, 1, 1, 0], [attack, sustain, release]), doneAction:2);
			var phase = Phasor.ar(0, rate, \startFrame.ir, \endFrame.ir);
			var snd = BufRd.ar(2, buf, phase);
			snd = snd * env;
			snd = Balance2.ar(snd[0], snd[1], rand * \randPanAmount.kr(0));
			Out.ar(\out.ir(0), snd * \level.ir(0.5));
		}).send(server);

		// Slice setup
		numOfSlices = 128;
		slices = Array.series(numOfSlices, 0, ((1.0 - 0.0) / (numOfSlices - 1)));
		activeSlices = [0];
		shortestFrameDuration = 1000;

		// settable callback per step.
		// this will after each synth is played, while the internal routine is waiting;
		// its argument is the index of the upcoming step.
		osc = NetAddr.new("127.0.0.1", 10111);
		stepCallback = { arg step;
			// osc.sendMsg("/step", step);
			postln("step " ++ step);
		};
		currentStep = 0;

		// Synth values
		playbackRate = 1.0;
		startPosition = 0.0;
		endPosition = 1.0;
		length = 0;
		attack = 0.01;
		release = 0.01;
		randFreq = 0.5;
		randLengthAmount = 0;
		randLengthUnquantized = false;
		randPanAmount = 0;
		level = 0.5;
	}


	wrapIndex { arg index;
		^index.wrap(0, activeSlices.size-1)
	}

	playCurrentStep {
		var buffer, duration, startSlice, startFrame, endSlice, endFrame, sliceLength, rand, randLength, defSymbol, synthArgs;
		// skip playing until one step is active
		while ({
			activeSlices.size < 1
		}, {
			postln("skipping step " ++ currentStep);
			this.setCurrentStep(currentStep + 1);
			0.1.wait;
		});
		buffer = sample;
		defSymbol = if(buffer.numChannels > 1, {
			\SampleSliceSequencer_1shot_env_raw_stereo;
		}, {
			\SampleSliceSequencer_1shot_env_raw_mono;
		});

		if (playbackRate > 0, {
			startFrame = 0;
			endFrame = buffer.numFrames - 1;
		}, {
			endFrame = 0;
			startFrame = buffer.numFrames - 1;
		});

		startSlice = slices[(activeSlices[currentStep]).min(slices.size - 2)];
		endSlice = slices[(activeSlices[currentStep] + 1).min(slices.size - 1)];

		// random length
		if (randLengthAmount > 0, {
			rand = rrand((randLengthAmount * -1) * 0.001, randLengthAmount * 0.001);
			startSlice = startSlice + rand;
			startSlice.max(0).min(1);

			if (randLengthUnquantized, {
				rand = rrand((randLengthAmount * -1) * 0.001, randLengthAmount * 0.001);
			});
			endSlice = endSlice + rand;
			endSlice.max(0).min(1);
		});

		// change slice length
		if (length > 0, {
			sliceLength = length.linlin(0, 100, endSlice, 1);
			endSlice = sliceLength;
		}, {
			sliceLength = length.linlin(-100, 0, startSlice, endSlice);
			endSlice = sliceLength;
		});

		startFrame = (endFrame * startSlice).max(0);
		endFrame = (endFrame * endSlice).max(startFrame + shortestFrameDuration).min(buffer.numFrames);
		duration = abs((endFrame - startFrame) / (server.sampleRate * playbackRate));
		[startFrame, endFrame, duration].postln;
		["step:" + currentStep, "slice:" + activeSlices[currentStep]].postln;

		synthArgs = [
			attack: attack,
			buffer: buffer.bufnum,
			duration: duration,
			endFrame: endFrame,
			level: level,
			rate: playbackRate,
			randFreq: randFreq,
			randPanAmount: randPanAmount,
			release: release,
			startFrame: startFrame,
		];

		server.bind({ synth = Synth.new(defSymbol, synthArgs, targetNode, addAction) });
		osc.sendMsg("/step", activeSlices[currentStep]);

		// this.stepCallback.value(activeSlices[currentStep]);
		this.setCurrentStep(currentStep + 1);

		duration.wait;
	}

	play {
		routine = Routine { inf.do {
			this.playCurrentStep;
		} };
		routine.play;
		("Routine started.").postln;
	}

	stop {
		routine.stop;
		("Routine stopped.").postln;
		currentStep = 0;
	}

	setCurrentStep { arg index;
		currentStep = this.wrapIndex(index);
	}

	setSample { arg path;
		var buf;
		this.stop();
		sample.free;
		buf = Buffer.read(server, path, action: {
			("Sample loaded.").postln;
			sample = buf;
			this.play();
		});
	}

	setNumOfSlices { arg totalSlices;
		numOfSlices = totalSlices;
		slices = Array.series(numOfSlices, 0, ((1.0 - 0.0) / (numOfSlices - 1)));
	}

	setSlice { arg slice;
		activeSlices = [slice];
	}

	setAll { arg slice, atk, len, lvl, rate, rFreq, rLen, rLenQ, rPan, rel;
		activeSlices = [slice.max(0).min(slices.size - 1)];
		attack = atk;
		length = len;
		level = lvl;
		playbackRate = rate;
		randFreq = rFreq;
		randLengthAmount = rLen;
		randLengthUnquantized = rLenQ;
		randPanAmount = rPan;
		release = rel;
	}

	free {
		this.stop();
		synth.free;
	}
}