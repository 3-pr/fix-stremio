#!/bin/bash

set -e

clear

cat << 'EOF'
                                                                       
                ===                
              =======              
            ===========            
          ===============          
        ===================        
       =====================       
     ++++++++++...=+++========     
   ++++++++++++......+++++++++++   
  +++++++++++++........++++++++++  
   ************......+*****+++++   
     **********...-***********     
       +++*****++************      
        ++++++++++++++++++*        
          +++++++++++++++          
            +++++++++++            
              +++++++              
                +++                
                                   
                     STREMIO DMG INSTALLER & RE-SIGNER (macOS)
                     Author   : Yasser Alharbi (@i0zzw)
                     follow me: @i0zzw
EOF

echo
echo "اختر وضع التثبيت:"
echo "1) تثبيت تلقائي (تحميل Stremio / Stremio Horizon)"
echo "2) لدي ملف DMG جاهز (استخدام مساره)"
echo
read -p "أدخل رقم الخيار ثم اضغط Enter: " MODE

# دالة التثبيت من ملف DMG (سواء تم تحميله أو كان جاهز)
install_from_dmg() {
  local DMG_FILE="$1"

  echo
  echo "جاري تركيب ملف DMG..."
  MOUNT_OUTPUT=$(hdiutil attach "$DMG_FILE" -nobrowse 2>&1)

  echo
  echo "------ hdiutil output ------"
  echo "$MOUNT_OUTPUT"
  echo "----------------------------"

  # استخراج مسار /Volumes/... من مخرجات hdiutil
  VOLUME_PATH=$(echo "$MOUNT_OUTPUT" | sed -n 's/.*\(\/Volumes\/.*\)$/\1/p' | head -n 1)

  if [[ -z "$VOLUME_PATH" ]]; then
    echo
    echo "❌ فشل في تحديد مسار الـ Volume من مخرجات hdiutil."
    exit 1
  fi

  if [[ ! -d "$VOLUME_PATH" ]]; then
    echo
    echo "❌ مجلد الـ Volume غير موجود:"
    echo "   $VOLUME_PATH"
    exit 1
  fi

  echo
  echo "تم تركيب ملف DMG في المسار:"
  echo "   $VOLUME_PATH"
  echo

  echo "جاري البحث عن التطبيق (.app) داخل ملف DMG..."
  APP_PATH=$(find "$VOLUME_PATH" -maxdepth 2 -name "*.app" 2>/dev/null | head -n 1)

  if [[ -z "$APP_PATH" ]]; then
    echo
    echo "❌ لم يتم العثور على أي ملف .app داخل:"
    echo "   $VOLUME_PATH"
    echo "يرجى التحقق من محتويات ملف DMG يدوياً."
    hdiutil detach "$VOLUME_PATH" -quiet 2>/dev/null || true
    exit 1
  fi

  APP_NAME=$(basename "$APP_PATH")
  TARGET_APP="/Applications/$APP_NAME"

  echo
  echo "تم العثور على التطبيق:"
  echo "   $APP_NAME"
  echo
  echo "سيتم تثبيته في:"
  echo "   $TARGET_APP"
  echo

  echo "جاري نسخ التطبيق إلى مجلد التطبيقات..."
  if [[ -d "$TARGET_APP" ]]; then
    echo "يوجد إصدار سابق، جاري حذفه..."
    sudo rm -rf "$TARGET_APP"
  fi

  sudo cp -R "$APP_PATH" /Applications/

  echo
  echo "جاري فك تركيب ملف DMG..."
  hdiutil detach "$VOLUME_PATH" -quiet 2>/dev/null || true

  echo
  echo "جاري إزالة قيود النظام (quarantine)..."
  sudo xattr -c -r "$TARGET_APP" 2>/dev/null || true
  echo "تمت إزالة القيود بنجاح."

  echo
  echo "جاري إزالة التوقيع الأصلي للتطبيق (إن وجد)..."
  sudo codesign --remove-signature "$TARGET_APP" 2>/dev/null || true
  echo "تمت إزالة التوقيع القديم."

  echo
  echo "جاري إعادة توقيع التطبيق..."
  sudo codesign --force --deep --sign - "$TARGET_APP" 2>/dev/null
  echo "تم توقيع التطبيق بنجاح."

  echo
  echo "جاري التحقق من التوقيع..."
  codesign -d -v -v "$TARGET_APP" 2>/dev/null || true

  echo
  echo "==============================================="
  echo " ✅ تم تثبيت التطبيق بنجاح"
  echo " اسم التطبيق: $APP_NAME"
  echo " المسار: $TARGET_APP"
  echo "==============================================="
  echo

  echo "جاري تشغيل التطبيق..."
  open "$TARGET_APP" 2>/dev/null || open -a "$APP_NAME" 2>/dev/null || true

  echo
  echo "انتهى."
}

DMG_FILE=""

case "$MODE" in
  1)
    echo
    echo "اختر النسخة التي تريد تثبيتها:"
    echo "1) Stremio الرسمي (Apple Silicon ARM64)"
    echo "2) Stremio Horizon (Apple Silicon ARM64)"
    echo

    read -p "أدخل رقم الخيار ثم اضغط Enter: " AUTO_CHOICE

    case "$AUTO_CHOICE" in
      1)
        STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.12/Stremio_arm64.dmg"
        echo
        echo "تم اختيار: Stremio الرسمي."
        ;;
      2)
        STREMIO_URL="https://github.com/Aqu1tain/stremio-horizon-app/releases/latest/download/Stremio.Horizon_0.2.1_aarch64.dmg"
        echo
        echo "تم اختيار: Stremio Horizon."
        ;;
      *)
        echo
        echo "❌ خيار غير صحيح."
        exit 1
        ;;
    esac

    TMP_DIR="$HOME/Downloads/stremio_installer_tmp"
    mkdir -p "$TMP_DIR"
    DMG_FILE="$TMP_DIR/stremio_installer.dmg"

    echo
    echo "جاري تحميل ملف DMG من الإنترنت..."
    echo "   $STREMIO_URL"
    curl -L "$STREMIO_URL" -o "$DMG_FILE"

    echo
    echo "تم التحميل إلى:"
    echo "   $DMG_FILE"
    ;;

  2)
    echo
    read -e -p "اسحب وأفلت ملف الـ DMG هنا ثم اضغط Enter: " DMG_FILE
    DMG_FILE="$(echo "$DMG_FILE" | xargs)"

    if [[ ! -f "$DMG_FILE" ]]; then
      echo
      echo "❌ لم يتم العثور على ملف DMG في المسار التالي:"
      echo "   $DMG_FILE"
      exit 1
    fi

    echo
    echo "سيتم استخدام ملف DMG التالي:"
    echo "   $DMG_FILE"
    ;;
  *)
    echo
    echo "❌ خيار غير صحيح."
    exit 1
    ;;
esac

# تنفيذ التثبيت من ملف DMG (سواء تم تحميله أو كان جاهز)
install_from_dmg "$DMG_FILE"
