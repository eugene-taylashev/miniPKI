# miniPKI
miniPKI is a set of scripts to build a simple PKI structure using OpenSSL.
Purposes:
* generate server or client X.509 certificates 
  * for mutual TLS verification/authentication
  * with SAN (Subject Alternative Name)
* Control certificate expiration
* Revoke a certificate

## Quick Start

* Clone the miniPKI: `git clone ` and change the directory: `cd miniPKI`
* Create a Certificate Authority (CA): `sudo bin/ca.sh`
* Create a Signing Authority (SA): `sudo bin/sa.sh`
* Create the chain of certificates CA+SA: `sudo cat certs/ca.crt certs/sa.crt >certs/ca-chain.pem`
* Create a private key and a certificate signing request (CSR): `sudo bin/gen.sh server1`
* Create a X.509 certificate from the CSR for a server: `sudo bin/sign.sh server1.csr`
* Check soon-to-expiry certificates: `sudo bin/check.sh`
* Revoke a certificate: `sudo bin/revoke.sh server1.crt`
* Create a certificate for MS Windows client
  * Create a private key and a certificate signing request (CSR): `bin/gen.sh client1`
  * Create a X.509 certificate from the CSR for a client: `sudo bin/sign.sh -c client1.csr`
  * Convert the certificate to the PFX format: `bin/convert2pfx -k client1.key -c client1.crt`


## Detailed Instructions
TBDef

### Step 1: Consider the prefix for your distinguished names (DNs)
Your distinguished name (DN) is the main part of access control using certificates


### Step 2: Create the root CA
Consider the following:
  - root CA's common name (CN). Could be *rootCA.example.com*. *ca* is used by default
  - validity period. 20 years are recommended
  
Run `bin/ca.sh [switch] [subject or hostname]`

If you used the non-default root name, update in the file ./lib/params.sh:
CA_KEY=$DIR_KEY/ca.key	#-- root CA private key
CA_CRT=$DIR_CRT/ca.crt  #-- root CA public certificate

You will use these parameters to sign SAs


### Step 3: Create Signing Authorities (SAs)
Consider the following:
  - SA's distinguished name (DN) or subject
  - validity period. 10 years are recommended
  - number of SAs. 1 for signing and 1 for backup

Run `bin/sa.sh [switch] [subject or hostname]`

Update the following in the file ./lib/params.sh with your working SA:

Now store the CA_KEY in a save place. It could be used to create new SAs or revoke compomized SAs

Create the file ca-chain.pem : `cat $CA_CRT $SA_CRT >./certs/ca-chain.pem`

### Step S+1: Creat a private key and a certificate signing request (CSR)

Run `bin/gen.sh [switch] subject_or_hostname`

## Description

The miniPKI directory and file structure:
* `./bin` - directory with executable scripts
  * `./bin/ca.sh` - generate a private key and a self-signed certificate for a Certificate Authority (CA). Run it only once.
  * `./bin/check.sh` - find soon-to-expire (60 days by default) certificates
  * `./bin/gen.sh` - generate a private key and a certificate signing request (CSR)
  * `./bin/revoke.sh` - revoke a certificate and update the certificate revocation list (CRL)
  * `./bin/sa.sh` - generate a private key and sign the certificate by CA for a Signing Authority (SA). Run it few times.
  * `./bin/sign.sh` - sign the CSR with SA's key to create Server or Client certificate
* `./certs` - directory for certificates
* `./certs.backup` - backup directory for certificates in format serial_index.pem
* `./crl` - directory for certificate revocation lists (CRL)
* `./csr` - directory for certificate signing requests (CSR)
* `./etc` - directory for configuration files
  * `./etc/params.sh` - file with common variables for scripts
  * `./etc/minipki.cnf` - configuration file for OpenSSL
* `./lib` - directory for other files
  * `./lib/crlnumber` - index for CRLs
  * `./lib/function.sh` - file with common functions for scripts
  * `./lib/index.txt` - list of certificates
  * `./lib/serial` - index for certificates
* `./log` - directory for logs. Purge these logs if too big
* `./private` - directory for SA private keys. It should have the highest protection

See Also:
* (How to create CSR with emailAddress)[https://stackoverflow.com/questions/38441426/how-to-create-csr-with-emailaddress-oneline]
* (OpenSSL Certificate Authority)[https://jamielinux.com/docs/openssl-certificate-authority/index.html]
