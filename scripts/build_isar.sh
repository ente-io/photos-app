# TODO: add `rustup@1.25.2` to `srclibs`
# TODO: verify if `gcc-multilib` or `libc-dev` is needed
$$rustup$$/rustup-init.sh -y
source $HOME/.cargo/env
cd thirdparty/isar/
bash tool/build_android.sh x86
bash tool/build_android.sh x64
bash tool/build_android.sh armv7
bash tool/build_android.sh arm64
mv libisar_android_arm64.so libisar.so
mv libisar.so $PUB_CACHE/hosted/pub.dev/isar_flutter_libs-*/android/src/main/jniLibs/arm64-v8a/
mv libisar_android_armv7.so libisar.so
mv libisar.so $PUB_CACHE/hosted/pub.dev/isar_flutter_libs-*/android/src/main/jniLibs/armeabi-v7a/
mv libisar_android_x64.so libisar.so
mv libisar.so $PUB_CACHE/hosted/pub.dev/isar_flutter_libs-*/android/src/main/jniLibs/x86_64/
mv libisar_android_x86.so libisar.so
mv libisar.so $PUB_CACHE/hosted/pub.dev/isar_flutter_libs-*/android/src/main/jniLibs/x86/
