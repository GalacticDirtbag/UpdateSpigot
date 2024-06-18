#!/bin/bash
VANILLA_VERSION_MANIFEST_URL=https://piston-meta.mojang.com/mc/game/version_manifest.json
VANILLA_VERSION_MANIFEST=$(curl -s "$VANILLA_VERSION_MANIFEST_URL")
LATEST_VANILLA_VERSION=$(echo "$VANILLA_VERSION_MANIFEST" | jq -r '.latest.release')
SPIGOT_VERSION_MANIFEST_URL=https://hub.spigotmc.org/versions/
SPIGOT_VERSION_MANIFEST=($(curl -s "$SPIGOT_VERSION_MANIFEST_URL" |\
                           grep -o -E '[0-9]\.[0-9]\.[0-9]|[0-9]\.[0-9][0-9]\.[0-9]|[0-9]\.[0-9][0-9]\.[0-9][0-9]|[0-9]\.[0-9][0-9]' |\
                           sort -t . -k 1,1n -k 2,2n -k 3,3n))
LATEST_SPIGOT_VERSION=$(echo "${SPIGOT_VERSION_MANIFEST[-1]}")
IS_SPIGOT=$(cat prevBuild.txt 2> /dev/null)

# User options:
# MC_SERVER_DIR = full path to the directory of your minecraft server
MC_SERVER_DIR=/srv/minecraft
# BUILD_TOOLS_DIR = full path to your BuildTools.jar
BUILD_TOOLS_DIR=/srv/minecraft/buildTools
# VANILLA_UPDATE = download vanilla Minecraft server if no Spigot parity
VANILLA_UPDATE=true


# Change working directory
pushd $BUILD_TOOLS_DIR

# Check if server jar exists
if [ -a $MC_SERVER_DIR/minecraft_server.jar ];
then
  # Get current server version
  CURRENT_SPIGOT_VERSION=$(unzip -p $MC_SERVER_DIR/minecraft_server.jar META-INF/versions.list | cut -d'-' -f 2 )

  # (Parsing vanilla version strings requires removing the extension)
  CURRENT_SPIGOT_VERSION=${CURRENT_SPIGOT_VERSION%.jar}
else
  CURRENT_SPIGOT_VERSION=$(echo "NONE")
fi

echo "The latest version of vanilla Minecraft server is $LATEST_VANILLA_VERSION."
echo "The latest version of Spigot Minecraft Server is $LATEST_SPIGOT_VERSION."
echo "You have version $CURRENT_SPIGOT_VERSION."
echo

# If server is not up to date or is vanilla
if [ "$CURRENT_SPIGOT_VERSION" != "$LATEST_VANILLA_VERSION" ] || ([ "$LATEST_SPIGOT_VERSION" == "$LATEST_VANILLA_VERSION" ] && [ "$IS_SPIGOT" != "spigot" ]);
then
  echo "Looks like you need an update."
  
  # If Spigot is up to date, build the new version
  if [ "$LATEST_SPIGOT_VERSION" == "$LATEST_VANILLA_VERSION" ];
  then
    echo "Downloading now..."

    # Clear any existing build artifacts, as this can cause build errors
    rm -R apache-maven-* BuildData Bukkit CraftBukkit Spigot work

    # Build the new version of Spigot
    java -jar BuildTools.jar --rev $LATEST_VANILLA_VERSION --output-dir $MC_SERVER_DIR --final-name minecraft_server.jar

    # Tell script server jar is Spigot on next run
    echo spigot > prevBuild.txt
  else
    echo "Hmm...Looks like Spigot isn't up-to-date yet."

    if [ "$VANILLA_UPDATE" == "true" ];
    then
      echo "Downloading vanilla..."
      # Determine the latest vanilla server version of Minecraft and download
      LATEST_VANILLA_MANIFEST=$(echo "$VANILLA_VERSION_MANIFEST" | jq -r --arg LATEST_VANILLA_VERSION "$LATEST_VANILLA_VERSION" '.versions | .[] | select(.id==$LATEST_VANILLA_VERSION) | .url')
      LATEST_VANILLA_MANIFEST_DATA=$(curl -s $LATEST_VANILLA_MANIFEST)
      VANILLA_JAR=$(jq -rn --argjson url "$LATEST_VANILLA_MANIFEST_DATA" '$url.downloads.server.url')
      curl -L $VANILLA_JAR -o $MC_SERVER_DIR/minecraft_server.jar

      # Tell script server jar is vanilla on next run
      echo vanilla > prevBuild.txt
    fi
  fi
else
  echo "Congrats! You're already up to date!"
fi
popd
