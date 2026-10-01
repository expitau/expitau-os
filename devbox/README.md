## X11 forwarding

**On host** 
- `xhost +` to allow connections
- `ssh -Y nathan@<ip>`

**On client**
- In /etc/ssh/ssh_config, ensure that ForwardX11 is yes
- `export XAUTHORITY=$HOME/.Xauthority`
- `chromium`


# Firewall

I had to add the following config to my firewall to allow masquerading

```
chain pstrt.lxdbr0 {
  type nat hook postrouting priority srcnat; policy accept;

  # Masquerade all packets leaving from lxdbr0 (outgoing to networks not lxdbr0)
  oifname != "lxdbr0" iifname "lxdbr0" masquerade
}
```
