MPENote : Object {
  var <manager, <ctl, <synth;

  *new { |manager|
    ^super.new.init(manager);
  }

  init { |pManager|
    ctl = MPEControls.new(onChange: { |e| this.onCtlChange(e) });
    manager = pManager;
  }

  vel { |x| ^this.ctl.value(\vel); }
  vel_ { |x| this.ctl.set(\vel, x); }

  num { |x| ^this.ctl.value(\num); }
  num_ { |x| this.ctl.set(\num, x); }

  bend { |x| ^this.ctl.value(\bend); }
  bend_ { |x| this.ctl.set(\bend, x); }

  pressure { |x| ^this.ctl.value(\pressure); }
  pressure_ { |x| this.ctl.set(\pressure, x); }

  timbre { |x| ^this.ctl.value(\timbre); }
  timbre_ { |x| this.ctl.set(\timbre, x); }

  set { |...args|
    ^this.ctl.set(*args);
  }

  onCtlChange { |e|
    if (synth.notNil && manager.notNil && manager.onChangeFn.notNil) {
      manager.onChangeFn.(manager, this, e);
    };
  }

  play {
    // initializes synth if it's not defined
    synth = synth ?? {
      var s = this.manager.getSynth(this);

      s.onFree {
        synth = nil;
        this.free;
      };

      s;
    };

    ^this;
  }

  release {
    if (synth.isNil) { ^this };

    // call onRelease
    if (manager.onReleaseFn.notNil) {
      manager.onReleaseFn.(this, synth);
    };

    synth.release;
    ^this;
  }

  free {
    if (synth.notNil) {
      synth.free;
      synth = nil;
    };

    // "FREEDOM! %\n".postf(this.num);
    ctl.free;
  }

}
