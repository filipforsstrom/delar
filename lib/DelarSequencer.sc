DelarSequencer {

	// initial variables
	var <server;
	var <targetNode;
	var <addAction;
	var <doneLoadingCallback;

	// sample data
	var buffer;

	var samplePlayer;
	var filter;
	var <filterParams;
	var delay;

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
	var <>attack;
	var <>release;
	var <>randFreq;
	var <>randStartPosition;
	var <>randEndPosition;
	var <>randPanAmount;
	var <>level;
	var <>busOutput;
	var <>fixedDuration;

	*new { arg server, targetNode, addAction, doneLoadingCallback;
		^super.newCopyArgs(server, targetNode, addAction, doneLoadingCallback).init
	}

	init {
		if (targetNode.isNil, { targetNode = server; });
		if (addAction.isNil, { addAction = \addToHead });

		filterParams = Dictionary.newFrom([
			\cutoff, 20000,
			\resonance, 0,
			\lfoSpeed, 1.0,
			\duration, 0,
			\t_gate, 0,
			\attack, 0.01,
			\release, 0.01,
			\modEnv, 0,
			\modLfo, 0,
			\level, 1.0,
		]);

		/*SynthDef.new(\Delay_stereo, {
			var sig = In.ar(\in.ir(14), 2);
			var del = CombN.ar(sig, 5, \time.kr(1), \feedback.kr(5));
			sig = sig.blend(del, \mix.kr(0.0));
			Out.ar(\out.ir(0), sig * \level.ir(1.0));
		}).send(server);

		server.bind({ delay = Synth.new(\Delay_stereo) });*/

		SynthDef.new(\Filter_stereo, {
			var sig = In.ar(\in.ir(10), 2);
			var duration = \duration.kr;
			var attack = \attack.kr(0.01).min(duration);
			var release = \release.kr(0.01).min(duration - attack);
			var sustain = (duration - (attack + release)).max(0);
			var env = EnvGen.ar(Env.new([0, 1, 1, 0], [attack, sustain, release]), \t_gate.kr(0));
			var lfo = SinOsc.kr(\lfoSpeed.kr(1.0));
			var mod = ((LinLin.kr(\modEnv.kr(0), -1, 1, -1000, 1000)) * env) + ((LinLin.kr(\modLfo.kr(0), -1, 1, -1000, 1000)) * lfo);
			var cutoff = Lag3.kr(\cutoff.kr(20000)) + mod;
			var resonance = Lag3.kr(\resonance.kr(1.0).max(0.1).min(1.0));
			var filter = BLowPass.ar(sig, cutoff.max(30).min(20000), resonance);
			Out.ar(\out.ir(0), filter * \level.kr(1.0));
		}).send(server);

		server.bind({ filter = Synth.new(\Filter_stereo) });

		SynthDef.new(\SamplePlayer_mono, {
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
			snd = Pan2.ar(snd, rand * \randPanAmount.kr(0));
			Out.ar(\out.kr(10), (snd * \level.kr(0.9)).dup);
		}).send(server);

		SynthDef.new(\SamplePlayer_stereo, {
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
			Out.ar(\out.ir(10), snd * \level.ir(0.9));
		}).send(server);

		osc = NetAddr.new("127.0.0.1", 10111);

		currentStep = 0;

		// Slice setup
		numOfSlices = 128;
		slices = Array.series(numOfSlices, 0, ((1.0 - 0.0) / (numOfSlices - 1)));
		shortestFrameDuration = 1000;
		activeSlices = [0];

		// samplePlayer values
		playbackRate = 1.0;
		startPosition = 0.0;
		endPosition = 1.0;
		length = 0;
		attack = 0.01;
		release = 0.01;
		randFreq = 0.5;
		randStartPosition = 0;
		randEndPosition = false;
		randPanAmount = 0;
		level = 0.5;
		busOutput = 10;
		fixedDuration = false;
	}


	wrapIndex { arg index;
		^index.wrap(0, activeSlices.size-1)
	}

	playCurrentStep {
		var duration, startSlice, startFrame, endSlice, endFrame, sliceLength, rand, randLength, defSymbol, samplePlayerArgs;
		// skip playing until one step is active
		while ({
			activeSlices.size < 1
		}, {
			postln("skipping step " ++ currentStep);
			this.setCurrentStep(currentStep + 1);
			0.1.wait;
		});

		defSymbol = if(buffer.numChannels > 1, {
			\SamplePlayer_stereo;
		}, {
			\SamplePlayer_mono;
		});

		startFrame = 0;
		endFrame = buffer.numFrames - 1;

		startSlice = slices[(activeSlices[currentStep]).min(slices.size - 2)];
		endSlice = slices[(activeSlices[currentStep] + 1).min(slices.size - 1)];

		// random length
		if (randStartPosition > 0, {
			rand = rrand((randStartPosition * -1) * 0.001, randStartPosition * 0.001);
			startSlice = startSlice + rand;
			startSlice.max(0).min(1);

			if (randEndPosition, {
				rand = rrand((randStartPosition * -1) * 0.001, randStartPosition * 0.001);
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
		if (fixedDuration, {
			duration = duration * playbackRate;
		});

		["start", "end", "playback rate", "duration"].postln;
		[startFrame, endFrame, playbackRate, duration].postln;
		["step:" + currentStep, "slice:" + activeSlices[currentStep]].postln;

		samplePlayerArgs = [
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
			out: busOutput,
		];

		server.bind({ samplePlayer = Synth.new(defSymbol, samplePlayerArgs, targetNode, addAction) });
		this.setFilterParam(\duration, duration);
		this.setFilterParam(\t_gate, 1);
		osc.sendMsg("/step", activeSlices[currentStep]);

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
		this.stop();
		buffer.free;
		buffer = Buffer.read(server, path, action: {
			("Sample loaded.").postln;
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

	setFilterParam { arg paramKey, paramValue;
		filter.set(paramKey, paramValue);
		filterParams[paramKey] = paramValue;
	}

	setAll { arg slice, atk, fDur, len, lvl, rate, rFreq, rStartPos, rEndPos, rPan, rel;
		activeSlices = [slice.max(0).min(slices.size - 1)];
		attack = atk;
		fixedDuration = fDur;
		length = len;
		level = lvl;
		playbackRate = rate;
		randFreq = rFreq;
		randStartPosition = rStartPos;
		randEndPosition = rEndPos;
		randPanAmount = (rPan * 0.01).max(0).min(1.0);
		release = rel;
	}

	freeSample {
		this.stop();
		samplePlayer.free;
	}

	free {
		this.stop();
		filter.free;
		samplePlayer.free;
		buffer.free;
	}
}