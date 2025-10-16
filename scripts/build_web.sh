#!/usr/bin/env bash
set -euo pipefail

# Install Flutter SDK (Linux x64) into a local cache dir
FLUTTER_VERSION="3.16.9" # stable, compact to speed up downloads on CI
SDK_DIR="/tmp/flutter_sdk"
if [ ! -d "$SDK_DIR" ]; then
  mkdir -p "$SDK_DIR"
  curl -L "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz
  tar -xJf /tmp/flutter.tar.xz -C "$SDK_DIR"
fi
export PATH="$SDK_DIR/flutter/bin:$PATH"

# Flutter tool warmup
flutter --version
flutter config --enable-web

# Prepare Supabase config from env (with safe defaults for preview builds)
mkdir -p lib/config
cat > lib/config/supabase_config.dart << 'EOF'
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: String.fromEnvironment('SUPABASE_URL_FALLBACK', defaultValue: 'https://kwunhuzfnjpcoeusnxzy.supabase.co'));
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY_FALLBACK', defaultValue: ''));
  static const bool useLocalSupabase = false;
  static String get url => supabaseUrl;
  static String get anonKey => supabaseAnonKey;
}
EOF

# Respect base href if provided by Vercel env
export FLUTTER_BASE_HREF="${FLUTTER_BASE_HREF:-/}"

flutter pub get
flutter build web --release

echo "Build completed. Output in build/web"


