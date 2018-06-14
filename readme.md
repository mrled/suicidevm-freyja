# Freyja

A SuicideVM for work

## Encrypted secrets

Secrets are encrypted and decrypted manually. (I haven't found a good automated solution that works on both Windows and Unix. For some reason people are writing these things in bash. In 2017. I know, I know.)

To encrypt a file called `example.secrets.json`, overwriting an encrypted `example.secrets.json.asc` if it exists:

    gpg --armor --encrypt --recipient "mledbetter@certicasolutions.com" example.secrets.json
    # Creates/overwrites example.secrets.json.asc

To decrypt the resulting `example.secrets.json.asc` file, overwriting the plaintext `example.secrets.json`:

    gpg --output example.secrets.json --decrypt example.secrets.json.asc

We have configured `.gitignore` to ignore all files with `secret` in the name, unless the filename also ends with `.asc` to indicate GPG encryption

## Lability

Run the included `Deploy-FREYJA.ps1` script to deploy the lab VM.
It will ask some questions about credentials if there isn't a decrypted secrets file at `secrets.FREYJA.json`.
Then it will deploy the lab.
