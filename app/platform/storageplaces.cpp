#include "storageplaces.h"

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#endif

namespace StoragePlaces {

#ifdef Q_OS_ANDROID
// Context.getExternalFilesDirs(null): the first is the shared storage on the device itself (the
// same memory as the app's data), the others are cards. A card that is not mounted is null.
QList<Place> cards()
{
    const QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return {};
    }

    QJniEnvironment env;
    const QJniObject dirs = context.callObjectMethod("getExternalFilesDirs", "(Ljava/lang/String;)[Ljava/io/File;", static_cast<jstring>(nullptr));
    if (env.checkAndClearExceptions() || !dirs.isValid()) {
        return {};
    }
    const QJniObject storage = context.callObjectMethod("getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;",
                                                        QJniObject::fromString(QStringLiteral("storage")).object<jstring>());

    QList<Place> places;
    const jsize count = env->GetArrayLength(dirs.object<jobjectArray>());
    for (jsize i = 1; i < count; ++i) {
        const QJniObject dir = QJniObject::fromLocalRef(env->GetObjectArrayElement(dirs.object<jobjectArray>(), i));
        if (!dir.isValid()) {
            continue;
        }
        const bool removable = QJniObject::callStaticMethod<jboolean>("android/os/Environment", "isExternalStorageRemovable",
                                                                      "(Ljava/io/File;)Z", dir.object());
        if (env.checkAndClearExceptions() || !removable) {
            continue;
        }

        // StorageManager.getStorageVolume(dir).getDescription(context): "SD card", in the system's words.
        QString label;
        if (storage.isValid()) {
            const QJniObject volume = storage.callObjectMethod("getStorageVolume", "(Ljava/io/File;)Landroid/os/storage/StorageVolume;",
                                                               dir.object());
            if (!env.checkAndClearExceptions() && volume.isValid()) {
                label = volume.callObjectMethod("getDescription", "(Landroid/content/Context;)Ljava/lang/String;",
                                                context.object()).toString();
                env.checkAndClearExceptions();
            }
        }
        places.append({dir.callObjectMethod("getAbsolutePath", "()Ljava/lang/String;").toString(), label});
    }
    return places;
}
#else
QList<Place> cards()
{
    return {};
}
#endif

}
