# Prompt you to enter the username and password
$credObject = Get-Credential

# The credObject now holds the password in a ‘securestring’ format
$passwordSecureString = $credObject.password

# Define a location to store the AESKey
$AESKeyFilePath = "C:\Users\administrator\Desktop\Automation\aeskey.txt"
# Define a location to store the file that hosts the encrypted password
$credentialFilePath = "C:\Users\administrator\Desktop\Automation\password.txt"

# Generate a random AES Encryption Key.
$AESKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($AESKey)

# Store the AESKey into a file. This file should be protected! (e.g. ACL on the file to allow only select people to read)

Set-Content $AESKeyFilePath $AESKey # Any existing AES Key file will be overwritten

$password = $passwordSecureString | ConvertFrom-SecureString -Key $AESKey

Add-Content $credentialFilePath $password