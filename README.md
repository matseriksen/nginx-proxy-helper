# 🚀 Nginx Proxy Script Features

## 📝 Overview
This **Bash script** automates the setup and management of **Nginx reverse proxies**, including **SSL handling** via Certbot.  
It allows users to **add, remove, list, and renew** proxies easily.

---

## 🌟 Features

### 1️⃣ Dependency Checking & Installation
✔️ Checks for required dependencies:  
   **`nginx`**, **`certbot`**, **`python3-certbot-nginx`**, **`curl`**, and **`ss`**.  

✔️ Automatically installs missing dependencies.

---

### 2️⃣ Domain & Port Validation
🔹 Ensures the provided **ports are valid** (1-65535).  
🔹 Checks if the **port is already in use**.  
🔹 Validates **domain names** to prevent misconfiguration.

---

### 3️⃣ Local Service Check
🔍 Verifies if a **local service is running** on the specified port before adding a proxy.  
⚠️ Logs a warning if **no response** is received from the local service.

---

### 4️⃣ Add Proxy
➕ Creates an **Nginx reverse proxy configuration**.  
🔗 Supports both **HTTP** and **HTTPS**.  
🔐 Automatically requests and configures an **SSL certificate** if a domain is provided.  
🛡️ Adds necessary **proxy headers** for security and proper forwarding.

---

### 5️⃣ Remove Proxy
🗑️ Deletes the **Nginx configuration** for a specific port.  
♻️ Reloads Nginx to apply changes.

---

### 6️⃣ List Active Proxies
📋 Displays currently **active reverse proxies** based on enabled Nginx configurations.

---

### 7️⃣ Renew SSL Certificates
🔄 Runs **`certbot renew`** to refresh SSL certificates for all configured domains.  
♻️ Reloads Nginx to apply the updated certificates.

---

### 8️⃣ Cleanup Function
🧹 Removes **all proxy configurations**.  
♻️ Reloads Nginx to reset the proxy settings.

---

### 9️⃣ Interactive Mode
🎛️ Guides users through adding, removing, listing, and renewing proxies with **prompts**.  
🖥️ Provides a **user-friendly selection menu**.

---

### 🔟 Logging
📝 Logs important actions (e.g., **proxy creation, SSL renewal**) to **`/var/log/nginx-proxy.log`**.

---

## 🔧 Usage

### ▶️ Run in Interactive Mode:
```bash
sudo ./nginx-proxy.sh interactive
