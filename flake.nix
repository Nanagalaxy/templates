{
  description = "Templates for what I use.";

  outputs =
    { self }:
    {
      templates = {
        dev = {
          path = ./dev;
          description = "Empty development environment";
        };
        python = {
          path = ./python;
          description = "Python development environment";
        };
        rust = {
          path = ./rust;
          description = "Rust development environment";
        };
      };

      templates.default = self.templates.dev;
    };
}
