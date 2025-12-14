MPEControls : Object {
  var controls, onChangeFn;

  *new { |onChange|
    ^super.newCopyArgs(
      controls: (),
      onChangeFn: onChange
    );
  }

  get { |key, defaultVal=0|
    controls[key] = controls[key] ?? { MPEControl(defaultVal) }
    ^controls[key];
  }

  value { |key, defaultVal=0|
    ^this.get(key, defaultVal).value;
  }

	// ctl.set(\vel, 100, \num, 50, ...);
	// ctl.set((vel: 100, num: 50));
  set { |...args|
		// allows pairs or event as params
		var e = if (args[0].isKindOf(Event)) { args[0] } { args.asEvent };

    // sets key/values into instance variables (e is an event that contains said key/values)
    e.keysValuesDo { |k, v|
      // "SET %: %\n".postf(k, v);
      this.get(k, v).set(v);
    };

    // call onChange
    if (onChangeFn.notNil) {
      onChangeFn.(e);
    };

    ^this;
  }

  bus { |key, defaultVal=0|
    ^this.get(key, defaultVal).bus;
  }

  ugen { |key, defaultVal=0|
    ^this.get(key, defaultVal).ugen;
  }

  free {
    controls.do { |ctl| ctl.free };
    controls = ();
  }
}
