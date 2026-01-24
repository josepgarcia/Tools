#!/bin/bash

set -euo pipefail

SCRIPTPATH=$(dirname "$0")
source $SCRIPTPATH/common.sh

###############################################

if ! [[ $# -eq 1 ]]; then
  echo 'Necesario 1 parámetro, nombre del plugin (en kebab-case sugerido)' 
  exit 1
fi

clear
echo -e "${BLUE}"
echo "+--------------------------+"
echo "| WP Plugin Scaffolding    |"
echo "+--------------------------+"
echo -e "${NC}"

PLUGIN_NAME=$1
# Convert to slug: lowercase and replace spaces/underscores with hyphens
PLUGIN_SLUG=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd '[:alnum:]-')
PLUGIN_DIR="$PLUGIN_SLUG"

if [[ -d "$PLUGIN_DIR" ]]; then
  echo -e "${RED}ERROR: La carpeta '$PLUGIN_DIR' ya existe ❌${NC}"
  exit 1
fi

echo "Creating plugin structure in: $PLUGIN_DIR ..."

# Create directory structure
mkdir -p "$PLUGIN_DIR/assets/css"
mkdir -p "$PLUGIN_DIR/assets/js"
mkdir -p "$PLUGIN_DIR/assets/images"
mkdir -p "$PLUGIN_DIR/inc"
mkdir -p "$PLUGIN_DIR/admin"
mkdir -p "$PLUGIN_DIR/public"

# Create index.php for security in all folders
find "$PLUGIN_DIR" -type d -exec touch "{}/index.php" \;
echo "<?php // Silence is golden" > "$PLUGIN_DIR/index.php"

# Main Plugin File
MAIN_FILE="$PLUGIN_DIR/$PLUGIN_SLUG.php"
CLASS_NAME=$(echo "$PLUGIN_NAME" | sed -E 's/(^|[-_ ])(.)/\U\2/g' | tr -d ' -_')
CONSTANT_NAME=$(echo "$PLUGIN_SLUG" | tr '-' '_' | tr '[:lower:]' '[:upper:]')

cat <<EOF > "$MAIN_FILE"
<?php
/**
 * Plugin Name:       $PLUGIN_NAME
 * Plugin URI:        https://josepgarcia.com
 * Description:       Descripción del plugin $PLUGIN_NAME.
 * Version:           1.0.0
 * Author:            Josep Garcia
 * Author URI:        https://josepgarcia.com
 * License:           GPL-2.0+
 * Text Domain:       $PLUGIN_SLUG
 */

// If this file is called directly, abort.
if ( ! defined( 'WPINC' ) ) {
	die;
}

/**
 * Currently active version of the plugin.
 */
define( '${CONSTANT_NAME}_VERSION', '1.0.0' );

/**
 * The core plugin class.
 */
class $CLASS_NAME {

	/**
	 * Define the core functionality of the plugin.
	 */
	public function __construct() {
		\$this->load_dependencies();
		\$this->define_admin_hooks();
		\$this->define_public_hooks();
	}

	/**
	 * Load the required dependencies for this plugin.
	 */
	private function load_dependencies() {
		// require_once plugin_dir_path( __FILE__ ) . 'inc/class-$PLUGIN_SLUG-helper.php';
	}

	/**
	 * Register all of the hooks related to the admin area functionality
	 */
	private function define_admin_hooks() {
		// add_action( 'admin_enqueue_scripts', array( \$this, 'enqueue_admin_styles' ) );
	}

	/**
	 * Register all of the hooks related to the public-facing functionality
	 */
	private function define_public_hooks() {
		// add_action( 'wp_enqueue_scripts', array( \$this, 'enqueue_public_styles' ) );
	}

	/**
	 * Run the plugin.
	 */
	public function run() {
		// Logic to start the plugin
	}
}

/**
 * Begins execution of the plugin.
 */
function run_$PLUGIN_SLUG() {
	\$plugin = new $CLASS_NAME();
	\$plugin->run();
}
run_$PLUGIN_SLUG();
EOF

echo -e "${GREEN}Plugin '$PLUGIN_NAME' created successfully in '$PLUGIN_DIR/' ✅${NC}"
printf '\n'
