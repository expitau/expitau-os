echo "Press enter to continue..."
read

echo "Installing initramfs hook"
cp ./initramfs_overlay_hook /etc/initcpio/hooks/overlay_root
cp ./initramfs_overlay_install /etc/initcpio/install/overlay_root

echo "Adding hook to mkinitcpio.conf"
# Replace HOOKS=.*fsck) with HOOKS=.*fsck overlay_root)
sed -i 's/^HOOKS=.*fsck\)/\1 overlay_root/' /etc/mkinitcpio.conf
echo "Regenerating initramfs"
mkinitcpio -P
