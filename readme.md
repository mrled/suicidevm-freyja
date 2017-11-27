# Freyja

A SuicideVM, brough to you by [WinTrialLab](https://github.com/mrled/wintriallab)

## Encrypted secrets

Secrets are encrypted and decrypted manually. (I haven't found a good automated solution that works on both Windows and Unix. For some reason people are writing these things in bash. In 2017. I know, I know.)

To encrypt a file called `example.secrets.json`, overwriting an encrypted `example.secrets.json.asc` if it exists:

    gpg --armor --encrypt --recipient "mledbetter@certicasolutions.com" example.secrets.json
    # Creates/overwrites example.secrets.json.asc

To decrypt the resulting `example.secrets.json.asc` file, overwriting the plaintext `example.secrets.json`:

    gpg --output example.secrets.json --decrypt example.secrets.json.asc

We have configured `.gitignore` to ignore all files with `secret` in the name, unless the filename also ends with `.asc` to indicate GPG encryption

## vagrant up

Multiple providers are defined in the Vagrant file, so you probably want to specify which one to bring up:

    vagrant up --provider hyperv
