{
  config,
  pkgs,
  lib,
  ...
}:
{
  # services.gnome.gnome-remote-desktop.enable = true;
  # networking.firewall.allowedTCPPorts = [ 3389 ];
  # environment.systemPackages = with pkgs; [
  #   gnome-remote-desktop
  #   openssl
  # ];

  # programs.dconf.profiles.user.databases = [{
  #   settings."org/gnome/desktop/remote-desktop/rdp" = {
  #     enable = true;
  #     view-only = false;
  #     tls-cert = "/home/nathan/.local/share/gnome-remote-desktop/tls.crt";
  #     tls-key = "/home/nathan/.local/share/gnome-remote-desktop/tls.key";
  #   };
  # }];

  # systemd.user.services.gnome-remote-desktop.wantedBy = [ "graphical-session.target" ];

  # --- OR ---

  # environment.systemPackages = [ pkgs.rustdesk-flutter ];

  # networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 21118 ];

  # systemd.services.rustdesk = {
  #   description = "RustDesk";
  #   after = [ "network.target" "systemd-user-sessions.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
  #     Restart = "always";
  #     KillMode = "mixed";
  #     LimitNOFILE = 100000;
  #   };
  # };

  # systemd.services.rustdesk-config = {
  #   description = "Apply RustDesk Tailscale-only settings";
  #   after = [ "rustdesk.service" ];
  #   requires = [ "rustdesk.service" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig.Type = "oneshot";
  #   script = ''
  #     sleep 3  # give the service time to open its IPC socket
  #     ${pkgs.rustdesk-flutter}/bin/rustdesk --option direct-server Y
  #     ${pkgs.rustdesk-flutter}/bin/rustdesk --option whitelist "100.64.0.0/10,fd7a:115c:a1e0::/48"
  #     ${pkgs.rustdesk-flutter}/bin/rustdesk --option custom-rendezvous-server 127.0.0.1
  #   '';
  # };
}
