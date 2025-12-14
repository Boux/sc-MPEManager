MPEControl : Object {
  var p_bus, p_value;

  bus {
    p_bus = p_bus ?? { Bus.control(Server.default) };
    ^p_bus;
  }

  value { ^p_value }
  value_ { |x|
    p_value = x;
    this.bus.set(x);
  }

  *new { |val|
    ^super.new.init(val);
  }

  init { |val|
    if (val.notNil) { this.set(val) };
  }

  set { |val|
    this.value = val;
  }

  ugen {
    ^In.kr(this.bus);
  }

  free {
    p_value = 0;
    try { p_bus.free };
  }
}
