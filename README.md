# Check the expiration date of your ssl-cert
![certcheck](pic/certcheck.png?raw=true)

## Fast bash script to see the expiration date of your ssl-cert
* You need a fast way to check the expiration date of an SSL certificate?
* You want it to be flexible and adjustable to your own needs?
* There you go!

## What' s in for you?
* TLS options like:
  * smtp
  * pop3
  * imap
  * ftp
  * xmpp
  * xmpp-server
* Simple command line interface
* Easy integrateable for monitoring e.g a cron service or icinga

## The Script can deal with these options:
* -H
  * Sets the value for the hostname. e.g adfinis-sygroup.ch
* -I
  * Sets an optional value for an IP to connect. e.g 127.0.0.1
* -p
  * Sets the value for the port. e.g 443
* -P
  * Sets an optional value for an TLS protocol. e.g xmpp
* -w
  * Sets the value for the days before warning. Default is 30
* -c
  * Sets the value for the days before critical. Default is 5
* -h


#### Example
```
./check_ssl.sh -H adfinis-sygroup.ch -p 443 -w 40
```
#### Or
```
./check_ssl.sh -H jabber.adfinis-sygroup.ch -p 5222 -P xmpp -w 30 -c 5
```
