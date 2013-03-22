use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::DOM;
use Time::Piece;
use Mango;
use Mango::BSON ':bson';

my $ua = Mojo::UserAgent->new;
my $uri = 'mongodb://localhost:27017/iata';
helper mango => sub { state $mango = Mango->new($uri) };

get '/' => sub{
	my $self = shift;

	$self->render('search');
};

get '/mango/:dep' => sub{ 
	my $self = shift;
	my $data = $self->mango->db->collection('codes')->find({City => $self->stash('dep')})->fields({_id => 0, City => 0})->all;
	say 'data found : '. $self->render(json=>$data, partial => 1);
	$self->render(json=>$data);
};

get '/mango' => sub{ 
	my $self = shift;
	my $data = $self->mango->db->collection('codes')->find({})->fields({_id => 0, IATA => 0})->all;
	$self->render(json=>$data);
};

get '/resultats' => sub{
	my $self = shift;
	$self->redirect_to('/resultats/'. $self->param('dep'). '/'. $self->param('arr'). '/'. 
		Time::Piece->strptime( $self->param('date'), "%d-%m-%Y")->strftime('%d%m%Y'));
};

get '/resultats/:dep/:arr/:date' => sub{ 
	my $self = shift;
	$self->stash(depIATA => $ua->get('/mango/'.$self->stash('dep'))->res->json('/0/IATA'));
	$self->stash(arrIATA => $ua->get('/mango/'.$self->stash('arr'))->res->json('/0/IATA'));
	$self->render('resultats');
};

get '/covoiturage' => sub {
	my $self = shift;
	my $date = $self->param('date');
	$date = Time::Piece->strptime($date, "%d%m%Y")->strftime('%d/%m/%Y');
	my $content = $ua->get('http://www.covoiturage.fr/recherche?fc='.$self->param('dep').'&tc='.$self->param('arr').'&to=VEHICLE&t=tripsearch&a=searchtrip&d='.$date)->
		res->dom('ul.search-results > li.one-trip:not(.one-trip-no-seat-available)');
	my $i = 0;
	my $trips = {};
	for my $trip (@$content)
	{
		$trips->{$i} = {
			title => $trip->at('div.one-trip-info > h2 > a')->text,
			date => $trip->at('div.one-trip-info > div > span.date')->text,
			price => $trip->at('div.one-trip-price > span.price > span')->text,
			url => $trip->at('div.one-trip-info > h2 > a')->attrs('href')
		};
		$trips->{$i}->{price} =~ s/â¬/€/;
		$trips->{$i}->{title} =~ s/→/>/;
		$trips->{$i}->{title} =~ s/Ã/E/;
		$trips->{$i}->{title} =~ s/Ã¨/E/;
		$trips->{$i}->{title} =~ s/Ãª/ê/;
		$trips->{$i}->{title} =~ s/Ã¢/â/;
		$i++;
	}

	$self->stash(pageContent => $trips);
	$self->render('covoiturage');
};

get '/trains' => sub {
	my $self = shift;
	my $date = $self->param('date');
	my $formdata = {
			back => 0, 
			originCode => '', 
			destinationCode => '', 
			originName =>  $self->param('dep'),
			destinationName =>  $self->param('arr'), 
			outwardJourneyDate => $date, 
			outwardJourneyHour => "00"};
	my $content = $ua->post('http://voyages-sncf.mobi/reservation/selectOD.action?selectv4=' => 
		form => $formdata)->
		res->dom;
	
	my $text = $content->find('div.bk-dv[style*=FFFFFF] > *:not(.bk-clr):not(br):not([style*=7B7B7B])');
	my $prices = Mojo::DOM->new($content->find('div.bk-headline[style*=FFFFFF] a'));
	my $trips = {};
	my $i = 0;
	my $j = 0;
	$text->each(sub {
    	my ($e, $count) = @_;
    	if(exists($trips->{$i}))
    	{
    		$trips->{$i}->{content} .= $e;
    	}
    	else{
	    	$trips->{$i} = {
	    		content => $e,
	    		price => $prices->find('[href*=outwardJourney='.$i.']')->[0]->text,
	    		id => $i,
	    		date => Time::Piece->strptime($date, "%d%m")->strftime('%d %B'),
	    		url => $prices->find('[href*=outwardJourney='.$i.']')->[0]{href}
	    	};
	    	$trips->{$i}->{price} =~ s/Â//;
	    	$trips->{$i}->{price} =~ s/â¬/€/;
    	}
    	$j++;
    	if($j >= 5)
    	{
	    	$i++;
	    	$j = 0;
    	}
	});

	while( my ($k,$v) = each(%$trips) ) {
		my $domContent = Mojo::DOM->new($v->{content});
		my $title = $domContent->find('b')->[1]->text .' > '. $domContent->find('b')->[2]->text;
		$trips->{$k}->{title} = ucfirst(lc($title));
		$trips->{$k}->{date} .= " - ".$domContent->find('b')->[0]->text;
	}

	$self->stash(pageContent => $trips);
	$self->stash(form => $formdata);
	$self->render('trains');
};

get '/avions' => sub {
	my $self = shift;
	return $self->render_text('<p>Destination non disponible</p>') if $self->param('dep') eq '';
	return $self->render_text('<p>Destination non disponible</p>') if $self->param('arr') eq '';
	my $date = $self->param('date');
	my $formdata =	{
			departure=>$self->param('dep'),
			arrival=>$self->param('arr'),
			typeTrip=>1,
			dayDate=>Time::Piece->strptime($date, "%d%m%Y")->strftime('%d'),
			yearMonthDate=>Time::Piece->strptime($date, "%d%m%Y")->strftime('%Y%m'),
			calendarSearch=>0,
			nbPassenger=>1,
			paxTypoList=>'ADT',
			cabin=>'Y',
			subCabin=>'MCHER',
			haul=>'SH',
			familyTrip=>'NON',
			jourAllerOrigine=>18,
			jourAllerFin=>14,
			moisAllerOrigine=>Time::Piece->strptime($date, "%d%m%Y")->strftime('%Y%m'),
			moisAllerFin=>'2014'.Time::Piece->strptime($date, "%d%m%Y")->strftime('%m')
			};
	my $content = $ua->post('http://www.airfrance.fr/cgi-bin/AF/FR/fr/local/process/standardbooking/ValidateSearchAction.do' => 
		form => $formdata)->
		res->dom;
	my $infos = $content->find('.calendar div.NFSCalendarCell');
	my $title = $content->find('.calendar div.NFSCalendarRecapEnTete')->pluck('text');
	my $trips = {};
	my $i = 0;

	$infos->each(sub {
    	my ($e, $count) = @_;
		my $domContent = Mojo::DOM->new($e);
	    $trips->{$i} = {
    		content => $e,
    		date => $domContent->find('div.NFSCalendarDate div')->pluck('text'),
    		price => $domContent->find('div.NFSCalendarPrice')->pluck('text'),
    		title => $title
    	};
	    $trips->{$i}->{price} =~ s/â¬/€/;
	    $trips->{$i}->{title} =~ s/Votre vol aller: //;
	    $trips->{$i}->{title} =~ s/à/>/;
    	$i++;
	});

	$self->stash(form => $formdata);
	$self->stash(pageContent => $trips);
	$self->render('avions');
};

app->start;