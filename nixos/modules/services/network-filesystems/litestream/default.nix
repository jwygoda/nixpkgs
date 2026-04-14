{
  config,
  lib,
  pkgs,
  ...
}:
let
  settingsFormat = pkgs.formats.yaml { };

  instanceOptions =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "litestream instance '${name}'";

        package = lib.mkPackageOption pkgs "litestream" { };

        settings = lib.mkOption {
          description = ''
            See the [documentation](https://litestream.io/reference/config/).
          '';
          type = settingsFormat.type;
          example = {
            dbs = [
              {
                path = "/var/lib/db1";
                replicas = [
                  {
                    url = "s3://mybkt.litestream.io/db1";
                  }
                ];
              }
            ];
          };
        };

        environmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = "/run/secrets/litestream";
          description = ''
            Environment file as defined in {manpage}`systemd.exec(5)`.

            Secrets may be passed to the service without adding them to the
            world-readable Nix store, by specifying placeholder variables as
            the option value in Nix and setting these variables accordingly in the
            environment file.

            By default, Litestream will perform environment variable expansion
            within the config file before reading it. Any references to ''$VAR or
            ''${VAR} formatted variables will be replaced with their environment
            variable values. If no value is set then it will be replaced with an
            empty string.

            ```
              # Content of the environment file
              LITESTREAM_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxxxxx
              LITESTREAM_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/xxxxxxxxx
            ```

            Note that this file needs to be available on the host on which
            this exporter is running.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "litestream-${name}";
          description = "User account under which the litestream instance '${name}' runs.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "litestream-${name}";
          description = "Group under which the litestream instance '${name}' runs.";
        };
      };
    };

  cfg = config.services.litestream;

  mkInstanceConfig =
    name: icfg:
    lib.mkIf icfg.enable {
      environment.systemPackages = [ icfg.package ];

      environment.etc."litestream-${name}.yml".source = settingsFormat.generate "litestream-${name}-config.yaml" icfg.settings;

      systemd.services."litestream-${name}" = {
        description = "Litestream (${name})";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          EnvironmentFile = lib.mkIf (icfg.environmentFile != null) icfg.environmentFile;
          ExecStart = "${icfg.package}/bin/litestream replicate -config /etc/litestream-${name}.yml";
          Restart = "always";
          User = icfg.user;
          Group = icfg.group;
        };
      };

      users.users.${icfg.user} = {
        description = "Litestream ${name} user";
        group = icfg.group;
        isSystemUser = true;
      };
      users.groups.${icfg.group} = { };
    };
in
{
  options.services.litestream = {
    enable = lib.mkEnableOption "litestream";

    package = lib.mkPackageOption pkgs "litestream" { };

    settings = lib.mkOption {
      description = ''
        See the [documentation](https://litestream.io/reference/config/).
      '';
      type = settingsFormat.type;
      example = {
        dbs = [
          {
            path = "/var/lib/db1";
            replicas = [
              {
                url = "s3://mybkt.litestream.io/db1";
              }
            ];
          }
        ];
      };
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/litestream";
      description = ''
        Environment file as defined in {manpage}`systemd.exec(5)`.

        Secrets may be passed to the service without adding them to the
        world-readable Nix store, by specifying placeholder variables as
        the option value in Nix and setting these variables accordingly in the
        environment file.

        By default, Litestream will perform environment variable expansion
        within the config file before reading it. Any references to ''$VAR or
        ''${VAR} formatted variables will be replaced with their environment
        variable values. If no value is set then it will be replaced with an
        empty string.

        ```
          # Content of the environment file
          LITESTREAM_ACCESS_KEY_ID=AKIAxxxxxxxxxxxxxxxx
          LITESTREAM_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx/xxxxxxxxx
        ```

        Note that this file needs to be available on the host on which
        this exporter is running.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "litestream";
      description = "User account under which litestream runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "litestream";
      description = "Group under which litestream runs.";
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceOptions);
      default = { };
      description = ''
        Named litestream instances. Each instance runs as a separate systemd
        service `litestream-<name>` with its own configuration file at
        `/etc/litestream-<name>.yml`.
      '';
      example = {
        grafana = {
          enable = true;
          user = "grafana";
          group = "grafana";
          settings = {
            dbs = [
              {
                path = "/var/lib/grafana/data/grafana.db";
                replicas = [ { url = "s3://mybkt.litestream.io/grafana"; } ];
              }
            ];
          };
        };
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ cfg.package ];
      environment.etc = {
        "litestream.yml" = {
          source = settingsFormat.generate "litestream-config.yaml" cfg.settings;
        };
      };

      systemd.services.litestream = {
        description = "Litestream";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
          ExecStart = "${cfg.package}/bin/litestream replicate";
          Restart = "always";
          User = cfg.user;
          Group = cfg.group;
        };
      };

      users.users.${cfg.user} = {
        description = "Litestream user";
        group = cfg.group;
        isSystemUser = true;
      };
      users.groups.${cfg.group} = { };
    })

    (lib.mkMerge (lib.mapAttrsToList mkInstanceConfig cfg.instances))
  ];

  meta.doc = ./default.md;
}
