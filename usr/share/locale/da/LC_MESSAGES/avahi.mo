��    �      ,  �   <
      �  �  �  h   a  �   �  i  �  b  %  �   �     "     1  %   D  5   j     �     �     �     �  "   �     �      
     +     F  	   _     i  "   ~  4   �  *   �  .        0     <  
   E     P     ^     p     �     �     �     �     �     �     	          4     I     ^     t     �     �     �     �     �     �     �          &     :     W     r     �  %   �  &   �  #   �  #     #   B  !   f  (   �  <   �  %   �           2     S  #   r     �     �  #   �  %   �  ?     	   X     b  %   v     �  
   �     �     �     �     �               #     3     D     Z     n     |     �  4   �     �     �     �          /     >     Q     f     ~     �     �     �     �     �  '   �     �  &      	   6      @      N      \      _      h      y      ~      �   L   �   ;   �      1!  "   P!     s!     �!     �!     �!     �!     �!  	   �!     �!  *   �!  $   �!  +   "  #   E"  7   i"  %   �"  "   �"  4   �"  (   #  (   H#     q#     �#     �#     �#     �#     �#     �#     �#     �#     	$  
   $     $  &    $  '   G$  ,   o$     �$     �$     �$     �$      �$  }  �$  �  v&  m   >)  �   �)  k  �*  �  ,  �   �.     ?/     M/  *   d/  D   �/     �/     �/     �/     �/  $   0     (0  !   B0     d0     �0     �0     �0  6   �0  C   �0  &   :1  ,   a1  
   �1     �1     �1     �1     �1     �1     �1     �1  "   2     >2     T2     j2     2     �2     �2     �2     �2     �2     3  "   3     ?3  
   R3  '   ]3     �3     �3     �3     �3     �3      �3  !   4  (   /4  3   X4  '   �4  %   �4  $   �4  %   �4  #   %5  +   I5  @   u5  (   �5  "   �5  #   6  &   &6  *   M6  "   x6     �6  #   �6  '   �6  B   7  
   E7     P7     i7     �7     �7     �7     �7     �7     �7     �7     �7     8     8     /8     E8     Z8     h8     |8  1   �8     �8     �8     �8     �8     9     (9     ;9     Q9     k9     �9     �9     �9     �9     �9  -   �9     �9  *    :     +:     7:     D:     W:     Z:     f:     {:     �:     �:  G   �:  6   �:     ,;  "   L;     o;     |;     �;     �;     �;     �;  	   �;     �;  *   �;  &   �;  )   <  #   A<  ?   e<  '   �<  ,   �<  :   �<  &   5=  %   \=     �=     �=     �=     �=     �=     �=     �=     �=     >  	   $>     .>     ;>  +   ?>  ,   k>  1   �>     �>     �>     �>      �>  %   ?     D   �   -       (                                     s      �       �   �   U   M   }       ]   &   :   �   f   #   �   �   I       B   �   �   �   �   �       �          ~   k          i         ,   �           $   )       !       �      �   �                 l   \   =   �   �       E   1   ^   y   u   x   R   t           �   {   8   P       b   e          /           Z       |   S       6   L   z   *       0       V       d      �       "       �   �   
   m   <      w              �          4   �   q   `       o          v      F   �   T   X   9   N   O   _       2      J   +   G   p           c   �   A   h              �       �   r           3   7   W          Y   �      @           '       Q   �          j   	             .      >       %       �           n   �   �   K          H      �      ?   g              5   C           ;   [   a        -h --help            Show this help
    -V --version         Show version
    -D --browse-domains  Browse for browsing domains instead of services
    -a --all             Show all services, regardless of the type
    -d --domain=DOMAIN   The domain to browse in
    -v --verbose         Enable verbose mode
    -t --terminate       Terminate after dumping a more or less complete list
    -c --cache           Terminate after dumping all entries from the cache
    -l --ignore-local    Ignore local services
    -r --resolve         Resolve services found
    -f --no-fail         Don't fail if the daemon is not available
    -p --parsable        Output in parsable format
     -k --no-db-lookup    Don't lookup service types
    -b --dump-db         Dump service type database
 %s [options]

    -h --help            Show this help
    -s --ssh             Browse SSH servers
    -v --vnc             Browse VNC servers
    -S --shell           Browse both SSH and VNC
    -d --domain=DOMAIN   The domain to browse in
 %s [options] %s <host name ...>
%s [options] %s <address ... >

    -h --help            Show this help
    -V --version         Show version
    -n --name            Resolve host name
    -a --address         Resolve address
    -v --verbose         Enable verbose mode
    -6                   Lookup IPv6 address
    -4                   Lookup IPv4 address
 %s [options] %s <name> <type> <port> [<txt ...>]
%s [options] %s <host-name> <address>

    -h --help            Show this help
    -V --version         Show version
    -s --service         Publish service
    -a --address         Publish address
    -v --verbose         Enable verbose mode
    -d --domain=DOMAIN   Domain to publish service in
    -H --host=DOMAIN     Host where service resides
       --subtype=SUBTYPE An additional subtype to register this service with
    -R --no-reverse      Do not publish reverse entry with address
    -f --no-fail         Don't fail if the daemon is not available
 %s [options] <new host name>

    -h --help            Show this help
    -V --version         Show version
    -v --verbose         Enable verbose mode
 : All for now
 : Cache exhausted
 <i>No service currently selected.</i> A NULL terminated list of service types to browse for Access denied Address Address family Address: An unexpected D-Bus error occurred Avahi client failure: %s Avahi domain browser failure: %s Avahi resolver failure: %s Bad number of arguments
 Bad state Browse Service Types Browse service type list is empty! Browsing for service type %s in domain %s failed: %s Browsing for services in domain <b>%s</b>: Browsing for services on <b>local network</b>: Browsing... C_onnect Canceled.
 Change domain Choose SSH server Choose Shell Server Choose VNC server Client failure, exiting: %s
 Connecting to '%s' ...
 DNS failure: FORMERR DNS failure: NOTAUTH DNS failure: NOTIMP DNS failure: NOTZONE DNS failure: NXDOMAIN DNS failure: NXRRSET DNS failure: REFUSED DNS failure: SERVFAIL DNS failure: YXDOMAIN DNS failure: YXRRSET Daemon connection failed Daemon not running Desktop Disconnected, reconnecting ...
 Domain Domain Name: E Ifce Prot %-*s %-20s Domain
 E Ifce Prot Domain
 Established under name '%s'
 Failed to add address: %s
 Failed to add service: %s
 Failed to add subtype '%s': %s
 Failed to connect to Avahi server: %s Failed to create address resolver: %s
 Failed to create browser for %s: %s Failed to create client object: %s
 Failed to create domain browser: %s Failed to create entry group: %s
 Failed to create host name resolver: %s
 Failed to create resolver for %s of type %s in domain %s: %s Failed to create simple poll object.
 Failed to parse address '%s'
 Failed to parse port number: %s
 Failed to query host name: %s
 Failed to query version string: %s
 Failed to read Avahi domain: %s Failed to register: %s
 Failed to resolve address '%s': %s
 Failed to resolve host name '%s': %s
 Failed to resolve service '%s' of type '%s' in domain '%s': %s
 Host Name Host name conflict
 Host name successfully changed to %s
 Initializing... Interface: Invalid DNS TTL Invalid DNS class Invalid DNS return code Invalid DNS type Invalid Error Code Invalid RDATA Invalid address Invalid argument Invalid configuration Invalid domain name Invalid flags Invalid host name Invalid interface index Invalid number of arguments, expecting exactly one.
 Invalid operation Invalid packet Invalid port number Invalid protocol specification Invalid record Invalid record key Invalid service name Invalid service subtype Invalid service type Is empty Local name collision Location Memory exhausted Name Name collision, picking new name '%s'.
 No command specified.
 No suitable network protocol available Not found Not permitted Not supported OK OS Error Operation failed Port Resolve Service Resolve Service Host Name Resolve the host name of the selected service automatically before returning Resolve the selected service automatically before returning Resource record key is pattern Server version: %s; Host name: %s
 Service Name Service Name: Service Type Service Type: TXT TXT Data TXT Data: Terminal The IP port number of the resolved service The TXT data of the resolved service The address family for host name resolution The address of the resolved service The domain to browse in, or NULL for the default domain The host name of the resolved service The object passed in was not valid The requested operation is invalid because redundant The service name of the selected service The service type of the selected service Timeout reached Too few arguments
 Too many arguments
 Too many clients Too many entries Too many objects Type Version mismatch Waiting for daemon ...
 _Cancel _Domain... _OK avahi_domain_browser_new() failed: %s
 avahi_service_browser_new() failed: %s
 avahi_service_type_browser_new() failed: %s
 empty execlp() failed: %s
 n/a service_browser failed: %s
 service_type_browser failed: %s
 Project-Id-Version: Avahi
Report-Msgid-Bugs-To: https://github.com/lathiat/avahi/issues
PO-Revision-Date: 2019-02-11 02:31+0000
Last-Translator: scootergrisen
Language-Team: Danish (http://www.transifex.com/lennart/avahi/language/da/)
Language: da
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
Plural-Forms: nplurals=2; plural=(n != 1);
     -h --help            Vis denne hjælp
    -V --version         Vis version
    -D --browse-domains  Find browsingdomæner i stedet for tjenester
    -a --all             Vis alle tjenester, uanset typen
    -d --domain=DOMÆNE   Domænet som der skal søges i
    -v --verbose         Aktivér uddybende tilstand
    -t --terminate       Afslut efter dumpning af en mere eller mindre fuldstændig liste
    -c --cache           Afslut efter dumpning af alle punkter i mellemlageret
    -l --ignore-local    Ignorer lokale tjenester
    -r --resolve         Løs fundne tjenester
    -f --no-fail         Giv ikke fejl hvis dæmonen ikke er tilgængelig
    -p --parsable        Uddata i fortolkeligt format
     -k --no-db-lookup    Slå ikke tjenestetyper op
    -b --dump-db         Dump database med tjenestetyper
 %s [tilvalg]

    -h --help            Vis denne hjælp
    -s --ssh             Find SSH-servere
    -v --vnc             Find VNC-servere
    -S --shell           Find både SSH og VNC
    -d --domain=DOMÆNE   Domænet som der skal søges i
 %s [tilvalg] %s <værtsnavn ...>
%s [tilvalg] %s <adresse ... >

    -h --help            Vis denne hjælp
    -V --version         Vis version
    -n --name            Løs værtsnavn
    -a --address         Løs adresse
    -v --verbose         Vis uddybende tilstand
    -6                   Slå IPv6-adresse op
    -4                   Slå IPv4-adresse op
 %s [tilvalg] %s <navn> <type> <port> [<tekst ...>]
%s [tilvalg] %s <værtsnavn> <adresse>

    -h --help              Vis denne hjælp
    -V --version           Vis version
    -s --service           Udgiv tjeneste
    -a --address           Udgiv adresse
    -v --verbose           Aktivér uddybende tilstand
    -d --domain=DOMÆNE     Domæne hvor tjeneste skal udgives i
    -H --host=DOMÆNE       Vært hvor tjeneste hører til
       --subtype=UNDERTYPE En ekstra undertype som tjenesten skal registreres med
    -R --no-reverse        Udgiv ikke modsat punkt med adresse
    -f --no-fail           Fejl ikke hvis dæmonen ikke er tilgængelig
 %s [tilvalg] <nyt værtsnavn>

    -h --help            Vis denne hjælp
    -V --version         Vis version
    -v --verbose         Aktivér uddybende tilstand
 : Alt for nu
 : Mellemlager opbrugt
 <i>Ingen tjeneste valgt i øjeblikket.</i> En NULL-afsluttet liste over tjenestetyper som der skal søges efter Adgang nægtet Adresse Adressefamilie Adresse: Der opstod en uventet fejl ved D-Bus Fejl ved Avahi-klient: %s Fejl ved Avahi-domænebrowser: %s Fejl ved Avahi-opløser: %s Ugyldigt antal argumenter
 Ugyldig tilstand Find tjenestetyper Listen over typer af tjenester der skal findes er tom! Forsøg på at finde tjenestetypen %s i domænet %s mislykkedes: %s Finder tjenester i domænet <b>%s</b>: Finder tjenester på <b>lokalt netværk</b>: Finder ... Opret _forbindelse Annulleret.
 Skift domæne Vælg SSH-server Vælg skal-server Vælg VNC-server Fejl ved klient, afslutter: %s
 Opretter forbindelse til '%s' ...
 Fejl ved DNS: FORMERR Fejl ved DNS: NOTAUTH Fejl ved DNS: NOTIMP Fejl ved DNS: NOTZONE Fejl ved DNS: NXDOMAIN Fejl ved DNS: NXRRSET Fejl ved DNS: REFUSED Fejl ved DNS: SERVFAIL Fejl ved DNS: YXDOMAIN Fejl ved DNS: YXRRSET Forbindelse til dæmon mislykkedes Dæmon kører ikke Skrivebord Afbrudt, opretter forbindelse igen ...
 Domæne Domænenavn: E Ifce Prot %-*s %-20s-domæne
 E Ifce Prot-domæne
 Etableret under navnet '%s'
 Kunne ikke tilføje adresse: %s
 Kunne ikke tilføje tjeneste: %s
 Kunne ikke tilføje undertypen '%s': %s
 Kunne ikke oprette forbindelse til Avahi-server: %s Kunne ikke oprette adresseopløser: %s
 Kunne ikke oprette browser for %s: %s Kunne ikke oprette klientobjekt: %s
 Kunne ikke oprette domænebrowser: %s Kunne ikke oprette punktgruppe: %s
 Kunne ikke oprette værtsnavnsopløser: %s
 Kunne ikke oprette opløser for %s af typen %s i domænet %s: %s Kunne ikke oprette simpelt poll-objekt.
 Kunne ikke fortolke adressen '%s'
 Kunne ikke fortolke portnummer: %s
 Kunne ikke forespørge værtsnavn: %s
 Kunne ikke forespørge versionsstreng: %s
 Kunne ikke læse Avahi-domæne: %s Kunne ikke registrere: %s
 Kunne ikke løse adressen '%s': %s
 Kunne ikke løse værtsnavnet '%s': %s
 Kunne ikke løse tjenesten '%s' af typen '%s' i domænet '%s': %s
 Værtsnavn Konflikt ved værtsnavn
 Værtsnavn ændret til %s
 Initialiserer ... Grænseflade: Ugyldig DNS-TTL Ugyldig DNS-klasse Ugyldig DNS-returkode Ugyldig DNS-type Ugyldig fejlkode Ugyldig RDATA Ugyldig adresse Ugyldigt argument Ugyldig konfiguration Ugyldigt domænenavn Ugyldige flag Ugyldigt værtsnavn Ugyldigt grænsefladeindeks Ugyldigt antal argumenter, ventede præcist ét.
 Ugyldig handling Ugyldig pakke Ugyldigt portnummer Ugyldig protokolspecifikation Ugyldig post Ugyldig postnøgle Ugyldigt tjenestenavn Ugyldig tjenesteundertype Ugyldig tjenestetype Er tom Lokal navnekollision Sted Hukommelse opbrugt Navn Navnesammenstød, vælger det nye navn '%s'.
 Ingen kommando angivet.
 Ingen egnet netværksprotokol tilgængelig Ikke fundet Ikke tilladt Ikke understøttet OK Fejl ved OS Handling mislykkedes Port Opløs tjeneste Opløs tjenestens værtsnavn Opløs værtsnavnet på den valgte tjeneste automatisk før returnering Opløs den valgte tjeneste automatisk før returnering Ressourcepostnøgle er mønster Serverversion: %s; værtsnavn: %s
 Tjenestenavn Tjenestenavn: Tjenestetype Tjenestetype: TXT TXT-data TXT-data: Terminal IP-portnummeret på den klarlagte tjeneste TXT-dataene på den klarlagte tjeneste Adressefamilien for værtsnavnsopløsning Adressen på den klarlagte tjeneste Domænet som der skal søges i, eller NULL for standarddomænet Værtsnavnet på den klarlagte tjeneste Objektet, der blev sat ind, var ikke gyldigt Den forespurgte handling er ugyldig på grund af redundans Tjenestenavnet på den valgte tjeneste Tjenestetypen på den valgte tjeneste Tiden løb ud For få argumenter
 For mange argumenter
 For mange klienter For mange punkter For mange objekter Type Forskellige versioner Venter på dæmon ...
 _Annuller _Domæne ... _OK avahi_domain_browser_new() mislykkedes: %s
 avahi_service_browser_new() mislykkedes: %s
 avahi_service_type_browser_new() mislykkedes: %s
 tom execlp() mislykkedes: %s
 - service_browser mislykkedes: %s
 service_type_browser mislykkedes: %s
 