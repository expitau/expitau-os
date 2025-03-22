#!/bin/bash

input_file="steamapps.conf"  # Replace with your actual file name

while IFS='=' read -r name id; do
    filename="$name.desktop"  # Replace spaces with underscores in the filename
    cat > "$filename" <<EOF
[Desktop Entry]
Name=$name
Comment=Play this game on Steam
Exec=steam steam://rungameid/$id
Icon=steam_icon_$id
Terminal=false
Type=Application
Categories=Game;
EOF
    echo "Created $filename"
done < "$input_file"
