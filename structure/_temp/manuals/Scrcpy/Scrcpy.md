

# Скачать с GitHub
    Scrcpy GUI (GeorgeEnglezos): https://github.com/GeorgeEnglezos/Scrcpy-GUI/releases
    Scrcpy: https://github.com/Genymobile/scrcpy/releases

# 📶 Инструкция по подключению через WiFi 

### **Включите режим TCP/IP (телефон должен быть подключен по USB кабелем в этот момент!)**
   .\adb tcpip 5555

### **Отключите USB-кабель. Подключитесь по WiFi (замените 192.168.3.XXX на реальный IP телефона)**
   .\adb connect 192.168.137.253:5555

### **Проверьте подключение:**
   .\adb devices
   Должно появиться:
   192.168.3.3:5555    device
   Если пусто — телефон не подключён

### **Перезапустите ADB:**
   .\adb kill-server
   .\adb start-server

### **Подключитесь вручную:**
   .\adb connect 192.168.3.3:5555   .\adb connect 192.168.137.253:5555       ftp://192.168.3.3:2221   ftp://192.168.137.253:2221

### **Проверьте:**
   .\adb devices

### **Запустите scrcpy:**
   .\scrcpy






