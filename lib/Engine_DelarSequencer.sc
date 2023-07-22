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
			kernel.freeSample();
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

		this.addCommand(\set_all, "ifffiffiff", { arg msg;
			var slice = msg[1] - 1;
			var attack = msg[2];
			var length = msg[3];
			var level = msg[4];
			var playbackRate = msg[5];
			var randFreq = msg[6];
			var randStartPosition = msg[7];
			var randEndPosition = msg[8];
			var randPanAmount = msg[9];
			var release = msg[10];

            if (randEndPosition == 0, {
                randEndPosition = false;
            } , {
                randEndPosition = true;
            });

			if (playbackRate == 0, {
				playbackRate = 1.0;
			} , {
				playbackRate = pow(2, playbackRate);
			});
            
			kernel.setAll(slice, attack, length, level, playbackRate, randFreq, randStartPosition, randEndPosition, randPanAmount, release);
		});

		this.addCommand(\set_filter, "sf", {arg msg;
			kernel.setFilterParam(msg[1].asSymbol, msg[2].asFloat);
		});


	} // alloc

	free {
		kernel.free();
	}


} // CroneEngine