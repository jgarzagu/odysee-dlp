# odysee-dlp

A small script to download odysee and lbry videos using lbrynet commands.

Using yt-dlp with Odysee videos often results in the videos becoming corrupted or incomplete. Likewise, downloading videos directly from the Odysee website can lead to corruption or incomplete downloads (due to network errors or long timeouts). The best method for downloading Odysee videos is to install the LBRY desktop application, as it includes **lbrynet**, a tool that interacts directly with the LBRY P2P network to handle downloads. However, when it comes to downloading a list of videos it's often tedious to do it manually, **odysee-dlp** helps with automating this task. It uses **lbrynet** internally for downlading a list of videos.

odysee-dlp is faster that yt-dlp, but the script has many limitations regarding options for its use.

# Download odysee-dlp

Create download folder

```sh
mkdir videoDownloads
cd videoDownloads
```

Downlaod odysee-dlp.sh

```sh
curl -sL -O https://raw.githubusercontent.com/jgarzagu/odysee-dlp/refs/heads/main/odysee-dlp.sh && chmod +x odysee-dlp.sh
```

# Run odysee-dlp (WSL)

1. Download lbrynet for Windows or Linux (https://lbry.com/get)

2. Locate lbrynet library

Example WSL Windows:

```sh
# C:\Program Files\LBRY\resources\static\daemon
/mnt/c/Program Files/LBRY/resources/static/daemon/lbrynet.exe
```

3. Run lbrynet deamon

Stop librynet deamon and start lbrynet deamon with main disc label you want to save the files (lbrynet can't figure out different disc locations):

```sh
cd /mnt/c/Program Files/LBRY/resources/static/daemon/
lbrynet.exe stop
lbrynet.exe start --download-dir "D:\\"
```

4. Create file links list

In a new terminal

```sh
cd videoDownloads
touch links.txt
echo "https://odysee.com/cyndriel-aldebaran-mystical-planet:f7e44b3bfbfd38acde6d6f04b55bcf9fb7e897e1" >> links.txt
echo "https://odysee.com/influence-on-our-past-of-the-urmah:0a5f42787a2e922417309a2e843ff5da87dccb4d" >> links.txt
```

4. Run odysee-dlp

```sh
./odysee-dlp.sh -b "/mnt/c/Program Files/LBRY/resources/static/daemon/lbrynet.exe" -l links.txt -o "D:\\PleiadianKnowledge\\download\\" -f "/mnt/d/PleiadianKnowledge/download"
```
