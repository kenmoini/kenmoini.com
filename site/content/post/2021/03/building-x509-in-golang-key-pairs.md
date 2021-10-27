---
title: "Building x509 PKI in Golang - Key Pairs - 8 / 100 DoC"
date: 2021-03-15T08:42:47-05:00
draft: false
toc: false
aliases:
    - /blog/building-x509-in-golang-key-pairs/
hero: /images/posts/heroes/go-pki-key-pairs.png
tags:
  - ssl
  - pki
  - x509
  - golang
  - programming
  - rsa
  - security
  - certificates
  - keys
  - encryption
authors:
  - Ken Moini
---

> ***Part 4 of a small series into building a Public Key Infrastructure chain with Golang***

Files and directories - check.  Now let's start to populate those directories with some keys for our Certificate Authority!

## Series Table of Contents

- [Background](https://kenmoini.com/blog/building-x509-in-golang-background/)
- [Directory Structure](https://kenmoini.com/blog/building-x509-in-golang-directory-structure/)
- [File Encryption](https://kenmoini.com/blog/building-x509-in-golang-file-encryption/)
- [Key Pairs](https://kenmoini.com/blog/building-x509-in-golang-key-pairs/)

## Key Pairs

Key Pairs are important as they're the fundamental crytographic component of PKI.  Let's create a few functions to create a Key Pair and save them to files with our Golang application that was started in the Directory Structure article.

*The final scripts and extra goodies will be provided at the end...whenever I finish writing all this...*

***Note:*** There are other kinds of Key Pair Algorithms you could use - for these purposes we'll go with trusy RSA.

### func.keys.go

```go
// generateRSAKeypair returns a private RSA key pair object
func generateRSAKeypair(keySize int) (*rsa.PrivateKey, *rsa.PublicKey, error) {
	if keySize == 0 {
		keySize = 4096
	}
	// create our private and public key
	privKey, err := rsa.GenerateKey(rand.Reader, keySize)
	if err != nil {
		return nil, nil, err
	}
	return privKey, &privKey.PublicKey, nil
}

// writeRSAKeyPair creates key pair files
func writeRSAKeyPair(privKey *bytes.Buffer, pubKey *bytes.Buffer, path string) (bool, bool, error) {
	privKeyFile, err := writeKeyFile(privKey, path+".priv.pem", 0400)
	if err != nil {
		return false, false, err
	}

	pubKeyFile, err := writeKeyFile(pubKey, path+".pub.pem", 0644)
	if err != nil {
		return privKeyFile, false, err
	}
	return privKeyFile, pubKeyFile, nil
}

// writeKeyFile writes a public or private key file depending on the permissions, 644 for public, 400 for private
func writeKeyFile(pem *bytes.Buffer, path string, permission int) (bool, error) {
	pemByte, _ := ioutil.ReadAll(pem)
	keyFile, err := WriteByteFile(path, pemByte, permission, false)
	if err != nil {
		return false, err
	}
	return keyFile, nil
}

// pemEncodeRSAPrivateKey creates a PEM from an RSA Private key, and optionally returns an encrypted version
func pemEncodeRSAPrivateKey(privKey *rsa.PrivateKey, rsaPrivateKeyPassword string) (privKeyPEM *bytes.Buffer, b *bytes.Buffer) {
	privKeyPEM = new(bytes.Buffer)
	b = new(bytes.Buffer)

	privateKeyBlock := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privKey),
	}

	/*
		Legacy encryption, insecure, replaced with AES-GCM encryption
		if rsaPrivateKeyPassword != "" {
			privateKeyBlock, _ = x509.EncryptPEMBlock(rand.Reader, privateKeyBlock.Type, privateKeyBlock.Bytes, []byte(rsaPrivateKeyPassword), x509.PEMCipherAES256)
		}
	*/

	pem.Encode(privKeyPEM, privateKeyBlock)

	if rsaPrivateKeyPassword != "" {
		encBytes := encryptBytes(privKeyPEM.Bytes(), rsaPrivateKeyPassword)
		b.Write(encBytes)
	}

	return privKeyPEM, b
}

// pemToEncryptedBytes takes a PEM byte buffer and encrypts it
func pemToEncryptedBytes(pem *bytes.Buffer, passphrase string) (b *bytes.Buffer) {
	b = new(bytes.Buffer)

	encBytes := encryptBytes(pem.Bytes(), passphrase)
	b.Write(encBytes)

	return b
}

// pemEncodeRSAPublicKey takes a DER formatted RSA Public Key object and converts it to PEM format
func pemEncodeRSAPublicKey(caPubKey *rsa.PublicKey) *bytes.Buffer {
	caPubKeyPEM := new(bytes.Buffer)
	pem.Encode(caPubKeyPEM, &pem.Block{
		Type:  "RSA PUBLIC KEY",
		Bytes: x509.MarshalPKCS1PublicKey(caPubKey),
	})
	return caPubKeyPEM
}
```

## Helper functions

Here are some additional functions that are in support of these Key Pair functions:

### func.file.go

```go
// FileExists checks if a file exists and returns a boolean or an erro
func FileExists(fileName string) (bool, error) {
	if _, err := os.Stat(fileName); err == nil {
		// path/to/whatever exists
		return true, nil
	} else if os.IsNotExist(err) {
		// path/to/whatever does *not* exist
		return false, nil
	} else {
		// Schrodinger: file may or may not exist. See err for details.
		// Therefore, do *NOT* use !os.IsNotExist(err) to test for file existence
		return false, err
	}
}
```

## Add Key Pair Generation to CreateNewCA function

Now we can add the key pair generation functions after the file system creation steps:

```go
// CreateNewCA was initially defined in one of the previous articles...
func CreateNewCA(certificateID string) (bool, []string, error) {

    // ...
    
    // Create the needed file structure for the CA
    caPaths := setupCAFileStructure(basePath)
    if caPaths.RootCAPath != basePath {
        return false, []string{"Error creating CA file structure!"}, err
    }
    
    // New Key Pair functions start here...
    
    // Check for certificate authority key pair
	caKeyCheck, err := FileExists(caPaths.RootCACertKeysPath + "/ca.priv.pem")
	check(err) // check function defined in previous article
	
	// Set a Password for the RSA Private Key file - or don't
	rsaPrivateKeyPassword := "s3cr3tP455"

	if !caKeyCheck {
		// if there is no private key, create one
		rootPrivKey, rootPubKey, err := GenerateRSAKeypair(4096)
		check(err)

		pemEncodedPrivateKey, encryptedPrivateKeyBytes := pemEncodeRSAPrivateKey(rootPrivKey, rsaPrivateKeyPassword)

		if rsaPrivateKeyPassword == "" {
			rootPrivKeyFile, rootPubKeyFile, err := writeRSAKeyPair(pemEncodedPrivateKey, pemEncodeRSAPublicKey(rootPubKey), certPaths.RootCAKeysPath+"/ca")
			check(err)
			if !rootPrivKeyFile || !rootPubKeyFile {
				return false, []string{"Root CA Private Key Failure"}, x509.Certificate{}, err
			}
		} else {

			encStr := B64EncodeBytesToStr(encryptedPrivateKeyBytes.Bytes())
			encBufferB := bytes.NewBufferString(encStr)

			rootPrivKeyFile, rootPubKeyFile, err := writeRSAKeyPair(encBufferB, pemEncodeRSAPublicKey(rootPubKey), certPaths.RootCAKeysPath+"/ca")
			check(err)
			if !rootPrivKeyFile || !rootPubKeyFile {
				return false, []string{"Root CA Private Key Failure"}, x509.Certificate{}, err
			}
		}
	}
    
    // More stuff to be added here later...
    
    return true, []string{"CA Created!"}, nil
}
```

## Next Steps

With that you should now have two files that provide your Root Certificate Authority a Public and Private RSA Key Pair.  Next up we'll be creating a Certificate Request for the Certificate Authority that will be self-signed since it's a Root CA.
