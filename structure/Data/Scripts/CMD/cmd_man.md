






# захватить профиль командой DISM:
DISM /Capture-Image /ImageFile:X:\Profile_User.wim /CaptureDir:C:\Users\Имя_Клиента /Name:ClientProfile /Compress:maximum /CheckIntegrity

    X:\ — буква вашей админ-флешки.
    Имя_Клиента — точное имя папки профиля (с учётом регистра).
    При нескольких профилях повторить для каждого: Profile_User2.wim и т.д.
    Верификация: После завершения выполните проверку структуры образа.

# Верификация(проверка) структуры образа:
DISM /Get-ImageInfo /ImageFile:X:\Profile_User.wim

    Если команда вернула размер и индекс — образ валиден.

# экран сети: У меня нет интернета → Продолжить ограниченную установку:
OOBE\BYPASSNRO

    Shift + F10 — для вызова cmd.


# развернуть профиль командой DISM:
DISM /Apply-Image /ImageFile:X:\Profile_User.wim /Index:1 /ApplyDir:C:\Users\Имя_Клиента

    X:\ — буква вашей админ-флешки.
    Имя_Клиента — точное имя папки профиля (с учётом регистра).
    При нескольких профилях повторить для каждого: Profile_User2.wim и т.д.
    После завершения: восстановление прав NTFS ACLs. Без этого шага Windows выдаст ошибку «Вход выполнен с временным профилем».

# восстановление прав NTFS ACLs:
takeown /F "C:\Users\Имя_Клиента" /R /D Y
icacls "C:\Users\Имя_Клиента" /grant:r Имя_Клиента:(OI)(CI)F /T

    Замените Имя_Клиента на реальное имя пользователя. 
    Команды должны вернуть Успешно обработано: ... файлов.

# Генерализация, фиксация Sysprep и захват эталонного образа:
cd /d C:\Windows\System32\Sysprep
sysprep.exe /generalize /oobe /shutdown /unattend:unattend.xml

    скопируйте файл unattend.xml в каталог C:\Windows\System32\Sysprep\.





