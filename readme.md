# PlanetExpress

Random french travel website crawler made with Mojolicious/Perl as a school project. Definitely not stable and not useable IRL. Code is f*cking ugly. You've been warned.

## Requirements

PlanetExpress requires these perl packages/softwares :

*	Mojolicious
*	Mango
*	MongoDB database

## Install

We won't go through cpan commands, we're going to suppose you're good enough at this if you're reading this.

MongoDB is required for IATA codes storage. A json file is provided with french-only airport codes in the database/ folder. To import these codes, make sure the mongo server is running and run the following line:

	mongoimport -d iata -c codes --type json --file ./database/iata.json

Adapt --file to where you're executing mongoimport, the example is ran from the code origin folder. Mongo should import around 40 objects or so. If your database is on the same server as the mojolicious server and with default configuration, the app should run on first try. If not, change line 10 in the app.pl file :

	my $uri = 'mongodb://<your user:login>@<your mongodb host>:<your port>/iata';

You can try out the app with morbo :

	morbo ./app.pl

You know the drill, have fun. Leaving this here as part of project instructions, not planning to do anything with this. Code and app is under WTFPL license.

## Anecdote

This project was named after the shipping company from Futurama as Mojolicious projects guideline demand at least a quote from the Simpsons/Futurama.