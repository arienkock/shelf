#!/bin/env bash
set -e
set -x
#                                                 888      888          
#                                                 888      888          
#                                                 888      888          
# 88888b.  888d888 .d88b.   8888b.  88888b.d88b.  88888b.  888  .d88b.  
# 888 "88b 888P"  d8P  Y8b     "88b 888 "888 "88b 888 "88b 888 d8P  Y8b 
# 888  888 888    88888888 .d888888 888  888  888 888  888 888 88888888 
# 888 d88P 888    Y8b.     888  888 888  888  888 888 d88P 888 Y8b.     
# 88888P"  888     "Y8888  "Y888888 888  888  888 88888P"  888  "Y8888  
# 888                                                                   
# 888                                                                   
# 888                                                          

# Parse required params
for i in "$@"
do
case $i in
    -n=*|--name=*)
    APP_ID="${i#*=}"
    shift
    ;;
    -s=*|--source=*)
    APP_SOURCE="${i#*=}"
    shift
    ;;
    -c=*|--config=*)
    APP_CONFIG_FILE="${i#*=}"
    shift
    ;;
    -d=*|--dir=*)
    CUSTOM_DIR="${i#*=}"
    shift
    ;;
    *)
    # unknown option
    ;;
esac
done

# Validate parameters
if [ -z "$APP_ID" ]; then echo "Passing an app name (-n=, --name=) is required"; exit 1; fi
if [ -z "$APP_SOURCE" ]; then echo "Passing an executable jar file location (-s=, --source=) is required"; exit 1; fi
if ! [[ $APP_ID =~ ^[a-zA-Z_\-]+$ ]]; then
  echo "The application name may only contain [a-zA-Z_\\-]"
  exit 1
fi

# Default installation location
if [ -z "$CUSTOM_DIR" ]; then
  APP_DIR="/usr/share/$APP_ID"
else
  APP_DIR="$CUSTOM_DIR"
fi

# Helper function to fetch a local, remote http(s)), or S3 file
get_file() 
{
  if [[ "$1" == http:* ]] || [[ "$1" == https:* ]]; then
    curl "$1" 2>/dev/null >"$2"
  elif [[ "$1" == s3:* ]]; then
    aws s3 cp "$1" "$2"
  elif [ -f "$1" ]; then
    cp "$1" "$2"
  else
    echo "File $1 does not exist"
    exit 1
  fi
}

#                                   888                                                    
#                                   888                                                    
#                                   888                                                    
#  .d8888b 888d888 .d88b.   8888b.  888888 .d88b.       888  888 .d8888b   .d88b.  888d888 
# d88P"    888P"  d8P  Y8b     "88b 888   d8P  Y8b      888  888 88K      d8P  Y8b 888P"   
# 888      888    88888888 .d888888 888   88888888      888  888 "Y8888b. 88888888 888     
# Y88b.    888    Y8b.     888  888 Y88b. Y8b.          Y88b 888      X88 Y8b.     888     
#  "Y8888P 888     "Y8888  "Y888888  "Y888 "Y8888        "Y88888  88888P'  "Y8888  888     

# Create service user if it doesn't exist
if id -u $APP_ID &>/dev/null; then
  usermod -d "$APP_DIR" "$APP_ID"
  chsh -s /sbin/nologin "$APP_ID"
else
  useradd -s /sbin/nologin -d "$APP_DIR" "$APP_ID"
fi

#      888 d8b                          888                    d8b                   
#      888 Y8P                          888                    Y8P                   
#      888                              888                                          
#  .d88888 888 888d888 .d88b.   .d8888b 888888 .d88b.  888d888 888  .d88b.  .d8888b  
# d88" 888 888 888P"  d8P  Y8b d88P"    888   d88""88b 888P"   888 d8P  Y8b 88K      
# 888  888 888 888    88888888 888      888   888  888 888     888 88888888 "Y8888b. 
# Y88b 888 888 888    Y8b.     Y88b.    Y88b. Y88..88P 888     888 Y8b.          X88 
#  "Y88888 888 888     "Y8888   "Y8888P  "Y888 "Y88P"  888     888  "Y8888   88888P' 

# Create app directory structure
mkdir -p "$APP_DIR"
if ! sudo -u "$APP_ID" [ -x $APP_DIR ]; then
  echo "Directory $APP_DIR is not accessible to user $APP_ID. Check the parent directory permissions."
  exit 1
fi
(cd "$APP_DIR" && mkdir -p bin lib conf logs)

#                                          .d888 d8b 888                   
#                                         d88P"  Y8P 888                   
#                                         888        888                   
#  .d8888b .d88b.  88888b.  888  888      888888 888 888  .d88b.  .d8888b  
# d88P"   d88""88b 888 "88b 888  888      888    888 888 d8P  Y8b 88K      
# 888     888  888 888  888 888  888      888    888 888 88888888 "Y8888b. 
# Y88b.   Y88..88P 888 d88P Y88b 888      888    888 888 Y8b.          X88 
#  "Y8888P "Y88P"  88888P"   "Y88888      888    888 888  "Y8888   88888P' 
#                  888           888                                       
#                  888      Y8b d88P                                       
#                  888       "Y88P" 

# Backup previous version
[ -f "$APP_DIR/lib/$APP_ID.jar" ] && mv "$APP_DIR/lib/$APP_ID.jar" "$APP_DIR/lib/$APP_ID.jar.bak"

# Copy JAR file
get_file "$APP_SOURCE" "$APP_DIR/lib/$APP_ID.jar"

# Copy config file
if [ -z "$APP_CONFIG_FILE" ]; then
  touch "$APP_DIR/conf/config.yml"
else
  get_file "$APP_CONFIG_FILE" "$APP_DIR/conf/config.yml"
fi


#          888                     888                                   d8b          888    
#          888                     888                                   Y8P          888    
#          888                     888                                                888    
# .d8888b  888888  8888b.  888d888 888888      .d8888b   .d8888b 888d888 888 88888b.  888888 
# 88K      888        "88b 888P"   888         88K      d88P"    888P"   888 888 "88b 888    
# "Y8888b. 888    .d888888 888     888         "Y8888b. 888      888     888 888  888 888    
#      X88 Y88b.  888  888 888     Y88b.            X88 Y88b.    888     888 888 d88P Y88b.  
#  88888P'  "Y888 "Y888888 888      "Y888       88888P'  "Y8888P 888     888 88888P"   "Y888 
#                                                                            888             
#                                                                            888             
#                                                                            888 
PROCESS_PLACEHOLDERS_CMD="sed \"s|%%APP_ID%%|$APP_ID|g; s|%%APP_DIR%%|$APP_DIR|g\""

cat << 'EOF' | eval $PROCESS_PLACEHOLDERS_CMD > "$APP_DIR/bin/start.sh"
#!/bin/bash
[[ "$USER" == "%%APP_ID%%" ]] || exec su -l -s /bin/sh -c "exec $0" %%APP_ID%%

exec &> >(exec logger -s -t "%%APP_ID%%")

trap 'kill -TERM $(jobs -p)' TERM
set -x

cd "%%APP_DIR%%"
shopt -s nullglob
for configfile in conf/*.sh ; do
  source "$configfile"
done

java -server -jar "lib/%%APP_ID%%.jar" server "conf/config.yml" &

wait
EOF

#                                         d8b                   d8b                            
#                                         Y8P                   Y8P                            
#                                                                                              
# 88888b.   .d88b.  888d888 88888b.d88b.  888 .d8888b  .d8888b  888  .d88b.  88888b.  .d8888b  
# 888 "88b d8P  Y8b 888P"   888 "888 "88b 888 88K      88K      888 d88""88b 888 "88b 88K      
# 888  888 88888888 888     888  888  888 888 "Y8888b. "Y8888b. 888 888  888 888  888 "Y8888b. 
# 888 d88P Y8b.     888     888  888  888 888      X88      X88 888 Y88..88P 888  888      X88 
# 88888P"   "Y8888  888     888  888  888 888  88888P'  88888P' 888  "Y88P"  888  888  88888P' 
# 888                                                                                          
# 888                                                                                          
# 888

# Make start script executable
chown "$APP_ID:$APP_ID" "$APP_DIR/bin/start.sh"
chmod 770 "$APP_DIR/bin/start.sh"

# Make log dir owned by service user
chown "$APP_ID:$APP_ID" "$APP_DIR/logs/"

# d8b                   888             888 888                                         d8b                  
# Y8P                   888             888 888                                         Y8P                  
#                       888             888 888                                                              
# 888 88888b.  .d8888b  888888  8888b.  888 888      .d8888b   .d88b.  888d888 888  888 888  .d8888b .d88b.  
# 888 888 "88b 88K      888        "88b 888 888      88K      d8P  Y8b 888P"   888  888 888 d88P"   d8P  Y8b 
# 888 888  888 "Y8888b. 888    .d888888 888 888      "Y8888b. 88888888 888     Y88  88P 888 888     88888888 
# 888 888  888      X88 Y88b.  888  888 888 888           X88 Y8b.     888      Y8bd8P  888 Y88b.   Y8b.     
# 888 888  888  88888P'  "Y888 "Y888888 888 888       88888P'  "Y8888  888       Y88P   888  "Y8888P "Y8888 

cat << 'EOF' | eval $PROCESS_PLACEHOLDERS_CMD > "/etc/init/$APP_ID.conf"
description "%%APP_ID%%"
stop on runlevel [!2345]
start on stopped rc
respawn
exec su -l -s /bin/sh -c "exec ./bin/start.sh" "%%APP_ID%%"
EOF

# Enable and start service
stop "$APP_ID" || true
start "$APP_ID"
