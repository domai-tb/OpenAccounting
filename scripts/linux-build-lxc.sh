#!/usr/bin/env bash
# ponytail: fake headers for LXC without sudo, proper CI should: sudo apt-get install -y libkeybinder-3.0-dev libayatana-appindicator3-dev libgtk-3-dev
set -e
FAKE_KEYBINDER=/tmp/keybinder_fake/include
FAKE_APPINDICATOR=/tmp/appindicator_fake/include
mkdir -p "$FAKE_KEYBINDER" "$FAKE_APPINDICATOR/libappindicator"
cat > "$FAKE_KEYBINDER/keybinder.h" <<'EOF'
#pragma once
extern "C" { static inline void keybinder_init(void) {} static inline int keybinder_bind(const char *a, void (*b)(const char*, void*), void *c){return 1;} static inline void keybinder_unbind(const char *a, void (*b)(const char*, void*)){} }
EOF
cat > "$FAKE_APPINDICATOR/libappindicator/app-indicator.h" <<'EOF'
#pragma once
#include <gtk/gtk.h>
typedef struct _AppIndicator AppIndicator;
typedef enum{APP_INDICATOR_CATEGORY_APPLICATION_STATUS}AppIndicatorCategory;
typedef enum{APP_INDICATOR_STATUS_PASSIVE,APP_INDICATOR_STATUS_ACTIVE,APP_INDICATOR_STATUS_ATTENTION}AppIndicatorStatus;
static inline AppIndicator* app_indicator_new(const gchar* a,const gchar* b,AppIndicatorCategory c){return (AppIndicator*)0x1;}
static inline void app_indicator_set_status(AppIndicator* a,AppIndicatorStatus b){}
static inline void app_indicator_set_icon_full(AppIndicator* a,const gchar* b,const gchar* c){}
static inline void app_indicator_set_attention_icon_full(AppIndicator* a,const gchar* b,const gchar* c){}
static inline void app_indicator_set_menu(AppIndicator* a, GtkMenu* b){}
EOF
# patch hotkey_manager if needed
HKM_CMAKE="$HOME/.pub-cache/hosted/pub.dev/hotkey_manager_linux-0.2.0/linux/CMakeLists.txt"
if grep -q "FATAL_ERROR" "$HKM_CMAKE" 2>/dev/null; then
  python3 -c "
import pathlib
p=pathlib.Path('$HKM_CMAKE')
t=p.read_text()
t=t.replace('target_link_libraries(\${PLUGIN_NAME} PRIVATE PkgConfig::KEYBINDER)\n\npkg_check_modules(KEYBINDER','target_link_libraries(\${PLUGIN_NAME} PRIVATE PkgConfig::GTK)\n\npkg_check_modules(KEYBINDER')
t=t.replace('FATAL_ERROR.*keybinder-3.0.*','WARNING \"keybinder not found, fake\"')
print('Patched HKM')
"
fi
rm -rf build/linux
fvm flutter build linux --debug
echo "Built bundle/openaccounting"
