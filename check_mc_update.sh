#!/bin/bash
VANILLA_VERSION_MANIFEST_URL=https://piston-meta.mojang.com/mc/game/version_manifest.json
VANILLA_VERSION_MANIFEST=$(curl -s "$VANILLA_VERSION_MANIFEST_URL")
LATEST_VANILLA_VERSION=$(echo "$VANILLA_VERSION_MANIFEST" | jq -r '.latest.release')
SPIGOT_VERSION_MANIFEST_URL=https://hub.spigotmc.org/versions/
SPIGOT_VERSION_MANIFEST=($(curl -s "$SPIGOT_VERSION_MANIFEST_URL" |\
                           grep -o -E '[0-9]\.[0-9]\.[0-9]|[0-9]\.[0-9][0-9]\.[0-9]|[0-9]\.[0-9][0-9]\.[0-9][0-9]' |\
                           sort -t . -k 1,1n -k 2,2n -k 3,3n))
LATEST_SPIGOT_VERSION=$(echo "${SPIGOT_VERSION_MANIFEST[-1]}")

pushd /srv/minecraft/buildTools
if [ -a ../minecraft_server.jar ];
then
  CURRENT_SPIGOT_VERSION=$(unzip -p ../minecraft_server.jar META-INF/versions.list | cut -d'-' -f 2)
else
  CURRENT_SPIGOT_VERSION=$(echo "NONE")
fi

echo "The latest version of vanilla Minecraft server is $LATEST_VANILLA_VERSION."
echo "The latest version of Spigot Minecraft Server is $LATEST_SPIGOT_VERSION."
echo "You have version $CURRENT_SPIGOT_VERSION."
echo

if [ "$CURRENT_SPIGOT_VERSION" != "$LATEST_VANILLA_VERSION" ];
then
  echo "Looks like you need an update. Downloading now..."
  if [ "$LATEST_SPIGOT_VERSION" == "$LATEST_VANILLA_VERSION" ];
  then
    java -jar BuildTools.jar --rev $LATEST_VANILLA_VERSION --output-dir .. --final-name minecraft_server.jar
  else
    echo "Hmm...Looks like Spigot isn't up-to-date yet. Downloading vanilla..."
    LATEST_VANILLA_MANIFEST=$(echo "$VANILLA_VERSION_MANIFEST" | jq -r --arg LATEST_VANILLA_VERSION "$LATEST_VANILLA_VERSION" '.versions | .[] | select(.id==$LATEST_VANILLA_VERSION) | .url')
    LATEST_VANILLA_MANIFEST_DATA=$(curl -s $LATEST_VANILLA_MANIFEST)
    VANILLA_JAR=$(jq -rn --argjson url "$LATEST_VANILLA_MANIFEST_DATA" '$url.downloads.server.url')
    curl -L $VANILLA_JAR -o ../minecraft_server.jar
  fi
else
  echo "Congrats! You're already up to date!"
fi
popd