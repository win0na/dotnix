{ homeDirectory }:
{
  model = {
    provider = "auto";
  };

  terminal = {
    backend = "local";
    cwd = homeDirectory;
    timeout = 180;
    lifetime_seconds = 300;
  };

  memory = {
    memory_enabled = true;
    user_profile_enabled = true;
  };

  compression = {
    enabled = true;
    threshold = 0.50;
    target_ratio = 0.20;
    protect_last_n = 20;
  };

  agent = {
    max_turns = 60;
    reasoning_effort = "medium";
  };
}
