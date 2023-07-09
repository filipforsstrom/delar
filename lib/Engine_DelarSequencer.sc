Engine_DelarSequencer : CroneEngine {
	var kernel;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc { // allocate memory to the following:
		kernel = DelarSequencer.new(Crone.server);

		this.addCommand(\play, "", {
			kernel.play();
		});

		this.addCommand(\stop, "", {
			kernel.stop();
		});

		this.addCommand(\setSample, "s", { arg msg;
			var path = msg[1];
			kernel.setSample(path);
		});

		this.addCommand(\set_num_slices, "i", { arg msg;
			var num = msg[1];
			kernel.setNumOfSlices(num);
		});

		this.addCommand(\set_slice, "i", { arg msg;
			var slice = msg[1];
			kernel.setSlice(slice);
		});

		this.addCommand(\set_all, "iffffffiff", { arg msg;
			var slice = msg[1] - 1;
			var attack = msg[2];
			var length = msg[3];
			var level = msg[4];
			var playbackRate = msg[5];
			var randFreq = msg[6];
			var randLengthAmount = msg[7];
			var randLengthUnquantized = false;
			var randPanAmount = msg[9];
			var release = msg[10];
			kernel.setAll(slice, attack, length, level, playbackRate, randFreq, randLengthAmount, randLengthUnquantized, randPanAmount, release);
		});

	} // alloc

	free {
		kernel.free();
	}


} // CroneEngine