/*
TODO:
- add srcID handling to target specific MIDI deviec (multi-track)
- use MPEControls in MPEManager to manage global controls (not only note-specific)
- extract midi binds logic so that it's configurable
- allow both basic midi and mpe instruments
*/

MPEManager : Object {
  var <notes, <ctl, <midiBinds, <getKeyFn, <getSynthFn, <onChangeFn, <onReleaseFn, <chan, <srcID, <>bendRange, <>trace;

  *new { |getSynth, onChange, onRelease, getKey, chan, srcID, bendRange=24|
    var instance = super.newCopyArgs(
      getSynthFn: getSynth,
      onChangeFn: onChange,
      onReleaseFn: onRelease,
      getKeyFn: getKey,
      bendRange: bendRange,
      chan: chan,
      srcID: srcID,
      ctl: MPEControls.new(onChange: { |e| instance.onCtlChange(e) }),
      notes: (),
      midiBinds: ()
    );

    ^instance;
  }

  *mpe { |getSynth, onChange, onRelease, getKey, chan, srcID, bendRange=24|
    ^this.new(getSynth, onChange, onRelease, getKey, chan, srcID, bendRange).bindMPE;
  }

  *midi { |getSynth, onChange, onRelease, getKey, chan, srcID, bendRange=2|
    ^this.new(getSynth, onChange, onRelease, getKey, chan, srcID, bendRange).bindMIDI;
  }


  set { |...args|
    ^this.ctl.set(*args);
  }

  onCtlChange { |e|
    if (onChangeFn.notNil) {
      onChangeFn.(this, nil, e);
    };
  }


  bind { |key, type, func, msgNum|
    midiBinds[key] = midiBinds[key] ?? {
      MIDIFunc({ |val, num, ch, src|
        var noteKey, note, args, is3Args;

        // these funcs only use val, ch, src
        is3Args = [\touch, \bend, \program].includes(type);
        args = [val, num, ch, src];
        if (is3Args) {
          src = ch;
          ch = num;
          num = nil;
          args = [val, ch, src];
        };

        noteKey = this.getKey(val, num, ch, src);
        note = notes.at(noteKey);

        if (trace == true) { "%: %, %, %, %, %\n".postf(type, noteKey, val, num, ch, src) };

        func.(note, noteKey, *args);
      }, msgNum: msgNum, msgType: type, chan: chan, srcID: srcID);
    }
  }

  bindMIDI {
    this.unbindAll;

    // note is no longer unique on channel
    getKeyFn = { |val, num, chan, src|
      [num, chan, src].join("_").asSymbol;
    };

    // bind on/off
    this.bindToggle;

    this.bind(\bend, \bend, { |note, key, val, chan, src|
      this.set(\bend, val.linlin(0, 2**14, bendRange * -1, bendRange));
    });

    ^this;
  }


  bindMPE {
    this.unbindAll;

    getKeyFn = { |val, num, chan, src|
      [chan, src].join("_").asSymbol;
    };

    // bind on/off
    this.bindToggle;

    this.bind(\bend, \bend, { |note, key, val, chan, src|
      note.set(\bend, val.linlin(0, 2**14, bendRange * -1, bendRange));
    });

    this.bind(\pressure, \touch, { |note, key, val, chan, src|
      note.set(\pressure, val.linlin(0, 127, 0, 1));
    });

    this.bind(\timbre, \control, { |note, key, val, num, chan, src|
      note.set(\timbre, val.linlin(0, 127, -1, 1));
    }, 74);

    ^this;
  }

  bindToggle {
    this.bind(\on, \noteOn, { |note, key, val, num, chan, src|
      if (note.notNil) { note.release };
      note = note ?? { MPENote(this) };

      note.set(\vel, val, \num, num);
      note.play;
      notes[key] = note;
    });

    this.bind(\off, \noteOff, { |note, key, val, num, chan, src|
      note.release;
      notes[key] = nil;
    });
  }

  unbindAll {
    midiBinds.do { |func, key|
      ("unbind_" ++ key).postln;
      func.free;
    };

    midiBinds = ();

    ^this;
  }


  getSynth { |note|
    ^this.getSynthFn.(this, note);
  }


  // get unique key for note (chan_src for MPE by default)
  getKey { |val, num, chan, src|
    if (getKeyFn.notNil) { ^getKeyFn.(val, num, chan, src).asSymbol };

    ^[chan, src].join("_").asSymbol;
  }

  free {
    this.unbindAll;
    notes.do { |n| n.free };
  }
}
