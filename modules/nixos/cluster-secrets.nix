{
  config,
  lib,
  pkgs,
  flakeRoot,
  ...
}:
# TODO: this is dogshit, fix later
#
# Publishes secrets/cluster/ into the cluster. secrets/secrets.nix lists what
# exists; the path it is listed under is the destination:
#
#   secrets/cluster/<namespace>/<KEY>.age   key <KEY> of secret `env` in <namespace>
let
  root = flakeRoot + "/secrets/cluster";

  registryMarker = ".docker-password.age";
  readTrimmed = path: lib.removeSuffix "\n" (builtins.readFile path);

  paths = map (lib.removePrefix "cluster/") (
    builtins.filter (lib.hasPrefix "cluster/") (
      builtins.attrNames (import (flakeRoot + "/secrets/secrets.nix"))
    )
  );
  split = path: lib.splitString "/" path;

  namespaces = lib.unique (map (path: builtins.head (split path)) paths);
  namesIn =
    namespace: pred:
    map (path: builtins.elemAt (split path) 1) (
      builtins.filter (
        path: builtins.head (split path) == namespace && pred (builtins.elemAt (split path) 1)
      ) paths
    );

  secretsIn =
    namespace:
    let
      dir = root + "/${namespace}";
      keys = namesIn namespace (name: !lib.hasSuffix registryMarker name);
      registries = namesIn namespace (lib.hasSuffix registryMarker);
      secretName = key: "cluster-${namespace}-${lib.removeSuffix ".age" key}";
    in
    lib.optional (keys != [ ]) {
      inherit namespace;
      name = "env";
      kind = "generic";
      keys = lib.listToAttrs (
        map (key: {
          name = lib.removeSuffix ".age" key;
          value = config.age.secrets.${secretName key}.path;
        }) keys
      );
    }
    ++ map (
      file:
      let
        name = lib.removeSuffix registryMarker file;
      in
      {
        inherit namespace name;
        kind = "docker-registry";
        server = readTrimmed (dir + "/${name}.docker-server");
        username = readTrimmed (dir + "/${name}.docker-username");
        password = config.age.secrets.${secretName file}.path;
      }
    ) registries;

  spec = (pkgs.formats.json { }).generate "cluster-secrets.json" (lib.concatMap secretsIn namespaces);
in
{
  _module.args.clusterSecretName = namespace: key: "cluster-${namespace}-${key}";

  age.secrets = lib.listToAttrs (
    lib.concatMap (
      namespace:
      map (file: {
        name = "cluster-${namespace}-${lib.removeSuffix ".age" file}";
        value.file = root + "/${namespace}/${file}";
      }) (namesIn namespace (_: true))
    ) namespaces
  );

  systemd.services.cluster-secrets = {
    description = "Publish host secrets into the cluster";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.kubectl
      pkgs.jq
    ];
    environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
    script = ''
      apply() { kubectl apply -f -; }

      for ns in $(jq -r '[.[].namespace] | unique[]' ${spec}); do
        kubectl create namespace "$ns" --dry-run=client -o yaml | apply
      done

      jq -c '.[]' ${spec} | while read -r secret; do
        field() { jq -r ".$1" <<<"$secret"; }
        ns=$(field namespace)
        name=$(field name)

        case $(field kind) in
          generic)
            args=()
            while IFS=$'\t' read -r key path; do
              args+=("--from-file=$key=$path")
            done < <(jq -r '.keys | to_entries[] | "\(.key)\t\(.value)"' <<<"$secret")
            kubectl create secret generic "$name" --namespace "$ns" "''${args[@]}" \
              --dry-run=client -o yaml | apply
            ;;
          docker-registry)
            kubectl create secret docker-registry "$name" --namespace "$ns" \
              --docker-server="$(field server)" \
              --docker-username="$(field username)" \
              --docker-password="$(cat "$(field password)")" \
              --dry-run=client -o yaml | apply
            ;;
        esac
      done
    '';
  };
}
