void Function()? scheduleCloudSyncUpload;

void notifyUserDataChangedForSync() {
  scheduleCloudSyncUpload?.call();
}
