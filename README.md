# ⚠ WARNING ⚠ : Not developed for the moment.

<h1 align="center"> Pi-hole for Android APK Installer </h1>

<img height="" width="" src="" alt="" />

**Note** : There is no endorsement or partnership between this page and [Raspberry Pi](https://www.raspberrypi.com/).

### Requirements:

- Rooted Android device

### Note to users of previous builds:

- Uninstall any previous versions of Linux Deploy or Pi Deploy and reboot your device.
- Failure to heed this advice will cause issues!

### Installation:

- Install the latest [Linux Deploy](https://github.com/meefik/linuxdeploy/releases/latest) APK
- Tap the main menu (**Three dots** at the top right of screen)
- Tap **Install**
- In a few minutes, the [Raspberry Pi Image](https://github.com/LeBazarDeBryan/Raspberry_Pi_for_Android/releases/latest/download/raspberry_pi.tgz) will be downloaded and installed on your device.
- When deployment is complete, tap **[  ▷ START ]**  to launch the instance.
- The instance will provide you with a password to login to Pi-hole webadmin or via SSH/RDP (Username: _android_, see screenshot below)
- **Note**: The password appears only once when the image is deployed, make sure you record this information.
- **Hint**:  The password text can be highlighted and copied to your clipboard for easier management. 

-----------------------------------------------------------
**INSTALLATION COMPLETE    ·    Raspberry Pi is running on your Android Device**

-----------------------------------------------------------
The Android device's IP is shown at the top of the Linux Deploy main window.  You can interact with Pi-hole in several ways, the examples below use IP **_10.73.0.31_** 

 - From a Windows desktop, connect via RDP **->** **```mstsc.exe /v:10.73.0.31```**

 - From a computer running Linux, connect via SSH **->** **```ssh android@10.73.0.31```**

 - Pi-hole administration is accessible from any browser on your network **->** **```http://10.73.0.31/admin```**

 - If your Android device has a display, you can RDP into the Pi-hole instance (as localhost) by installing the [Microsoft Remote Desktop](https://play.google.com/store/apps/details?id=com.microsoft.rdc.androidx) client.
