{ profile, ... }:
let
  identity =
    if profile == "work" then
      {
        name = "Joona Kärkkäinen";
        email = "joona.karkkainen@netlight.com";
      }
    else
      {
        name = "Joona Kärkkäinen";
        email = "joona.karkkainen@gmail.com";
      };
in
{
  programs.git = {
    enable = true;
    ignores = [
      "*.swp"
      ".DS_STORE"
    ];
    signing.format = null;
    settings = {
      user = {
        inherit (identity) name email;
      };
      init.defaultBranch = "main";
      core.autocrlf = "input";
      branch.sort = "-committerdate";
      merge.conflictstyle = "zdiff3";
      pull.ff = "only";
      rerere.enabled = true;
    };
    lfs.enable = true;
  };
}
