
use <MCAD/involute_gears.scad>  
$fn = 40; // Auflösung   

// --- PARAMETER --- 
modul = 5;          
z_hohlrad = 36;      
z_planet = 24;        
r_hohlrad = (z_hohlrad * modul) / 2;  
r_planet = (z_planet * modul) / 2;    
achsabstand = r_hohlrad - r_planet;  // 30
exzenter_r = 12;                   // Abstand des Stifts zur Zahnradmitte  

// Pleuel & Kolben Parameter
pleuel_l = 200;                    // Länge der Pleuelstange
kolben_breite = 80;
kolben_hoehe = 40;

// --- ANIMATION --- 
winkel_arm = $t * 720;  
winkel_planet = -winkel_arm * (z_hohlrad / z_planet);   

// --- KORRIGIERTE BERECHNUNG DER EXZENTER-POSITION (GLOBAL) ---
// Entspricht exakt der Transformation: rotate(winkel_arm) -> translate(achsabstand auf Y)
planet_x = -achsabstand * sin(winkel_arm); 
planet_y =  achsabstand * cos(winkel_arm);

// Entspricht der internen Drehung des Planetenrads um sich selbst
winkel_pin_global = winkel_arm + winkel_planet;
pin_rel_x = -exzenter_r * sin(winkel_pin_global);
pin_rel_y =  exzenter_r * cos(winkel_pin_global);

// Absolute globale Koordinate des Pins
pin_x = planet_x + pin_rel_x;
pin_y = planet_y + pin_rel_y;

// --- KORRIGIERTE KOLBEN-POSITION & PLEUEL-RICHTUNG ---
// Durch das Vorzeichen steuern wir, dass der Kolben immer in die korrekte Richtung drückt
kolben_y = pin_y - sqrt(pow(pleuel_l, 2) - pow(pin_x, 2));

// Der korrigierte Winkel zieht die Pleuelstange jetzt sauber zum Kolbenkopf mit
winkel_pleuel = atan2(-pin_x, kolben_y - pin_y);


// --- KOMPONENTEN ZUSAMMENBAUEN --- 

// 1. Festes Hohlrad
color("LimeGreen", 0.4) festes_hohlrad(z_hohlrad, modul);  

// 2. Rotierendes Planetenrad
rotate([0, 0, winkel_arm])  
{  
    translate([0, achsabstand, 0])          
        rotate([0, 0, winkel_planet])          
            color("Orange") planeten_rad(z_planet, modul, exzenter_r); 
}   

// 3. Pleuelstange (Sitzt nun fest auf dem Pin und zeigt linear zum Kolben)
translate([pin_x, pin_y, 7])
    rotate([0, 0, -winkel_pleuel])
        color("LightBlue") pleuel_stange(pleuel_l);

// 4. Kolben (Läuft jetzt flüssig auf der Y-Achse mit)
translate([0, kolben_y, 7])
    color("Tomato") kolben(kolben_breite, kolben_hoehe);

// 5. STARRE ZYLINDERWÄNDE / FÜHRUNGSSCHIENEN (Bewegen sich NICHT mehr mit!)
// Wir berechnen den tiefsten und höchsten Punkt, den der Kolbenboden erreichen kann
y_minimal = -(achsabstand + exzenter_r + pleuel_l);
y_maximal = (achsabstand + exzenter_r - pleuel_l) + kolben_hoehe/2;
zylinder_laenge = abs(y_maximal - y_minimal) + 20;

color("Gray", 0.3) 
{
    // Linke Wand
    translate([-(kolben_breite/2 + 2), y_minimal - 10, 2]) 
        cube([2, zylinder_laenge, 15]);
    
    // Rechte Wand
    translate([(kolben_breite/2), y_minimal - 10, 2]) 
        cube([2, zylinder_laenge, 15]);
    
    // Zylinderkopf (Verschluss am oberen Ende bei y_maximal)
    // Er verbindet die linke und rechte Wand stabil miteinander
    translate([-(kolben_breite/2 + 2), y_minimal -10, 2]) 
        cube([kolben_breite + 4, 3, 15]);
}

// --- 6. VEREINFACHTER ZÜNDFUNKEN ---
// Modulo 720 sorgt dafür, dass der Funke nur alle 2 Umdrehungen aufblitzt (Viertakt-Prinzip).
// Der Funke zündet kurz vor dem oberen Totpunkt (OT) bei 720° (bzw. 0°).
winkel_viertakt = winkel_arm % 720;

// Zündfenster: 10° vor dem OT bis zum OT
ist_zuendung = (winkel_viertakt >= 524 && winkel_viertakt <= 534);

if (ist_zuendung) 
    {
    // Platziert den gelben Punkt direkt unter dem Zylinderkopf
    translate([0, y_minimal - 10, 9]) 
        {
        color("Yellow") {
            sphere(r = 10); // Der einfache gelbe Punkt
        }
    }
}

// --- 7. EINLASS- & AUSLASS-SIMULATION (VIERTAKTER) ---
// Positionen für die virtuellen Kanäle knapp unter dem Zylinderkopf
einlass_pos_x  = -(kolben_breite/2 - 6);
auslass_pos_x =  (kolben_breite/2 - 6);
kanal_y       = y_minimal - 8;

// Takt 1: Ansaugen (Einlasskanal öffnet sich blau)
ist_ansaugen = (winkel_viertakt >= 187 && winkel_viertakt < 360);
if (ist_ansaugen) {
    translate([einlass_pos_x, kanal_y, 9]) {
        color("DodgerBlue", 0.8) sphere(r = 7);
    }
}

// Takt 4: Ausstossen (Auslasskanal öffnet sich grau/schwarz)
ist_ausstossen = (winkel_viertakt >= 1 && winkel_viertakt <= 187);
if (ist_ausstossen) {
    translate([auslass_pos_x, kanal_y, 9]) {
        color("DimGray", 0.8) sphere(r = 7);
    }
}

// --- RECHNERISCHE MODULE ---  

module zahnrad_form(z_anzahl, m)  
{  
    gear(number_of_teeth = z_anzahl, circular_pitch = m * 180); 
}  

module festes_hohlrad(z, m)  
{  
    r_aussen = ((z * m) / 2) + 8;  
    difference()      
    {  
        cylinder(r = r_aussen, h = 7, center = false);  
        zahnrad_form(z, m);                                    
        cylinder(r = (z*m)/2 - 2, h = 20, center = true);      
    }  
}  

module planeten_rad(z, m, exzenter)  
{  
    union()      
    {  
        difference()          
        {  
            zahnrad_form(z, m);  
            cylinder(r = 3, h = 10, center = true);  
        }  
        // Der Exzenter-Pin
        translate([0, exzenter, 2])             
            cylinder(r = 2.5, h = 10, center = false);  
    }  
}  

module pleuel_stange(laenge)
{
    difference() {
        linear_extrude(height = 4) {
            hull() {
                circle(r = 5);
                translate([0, laenge, 0]) circle(r = 5);
            }
        }
        translate([0, 0, -1]) cylinder(r = 2.7, h = 7);
        translate([0, laenge, -1]) cylinder(r = 2.7, h = 7);
    }
}

module kolben(b, h)
{
    difference() 
    {
        translate([-b/2, -kolben_hoehe/2, 0]) cube([b, h, 12]);
    }
}
