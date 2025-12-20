{
  description = "Templates for what I use.";

  outputs = { self }: {
    templates = {
      dev = {
        path = ./dev;
        description = "Basic flake to start development environment";
      };
    };

    templates.default = self.templates.dev;
  };
}
