"""Original REDLINE roster data. Sources and estimation status travel with each row."""
from pathlib import Path
import json, math
ROOT=Path(__file__).resolve().parents[1]
# id, make, model, year, requested group, hp, hp rpm, Nm, Nm rpm, kg, drive, engine, limiter, gearbox, final, radius, price, reference quarter
ROWS=[
('miata','Mazda','MX-5 Miata',1990,'E',116,6500,136,5500,1002,'RWD','1.6L NA I4',7200,'manual5',4.30,.289,0,16.8),
('civic_si','Honda','Civic Si',1999,'E',160,7600,150,7000,1180,'FWD','1.6L NA I4',8000,'manual5',4.40,.291,5200,15.7),
('gti_vr6','Volkswagen','Golf GTI VR6',1997,'E',172,5800,235,4200,1280,'FWD','2.8L NA VR6',6500,'manual5',3.389,.298,6000,15.5),
('rsx','Acura','RSX Type-S',2003,'E',200,7400,193,6000,1252,'FWD','2.0L NA I4',7900,'manual6',4.389,.306,8500,15.1),
('brz','Subaru','BRZ',2013,'E',200,7000,205,6400,1253,'RWD','2.0L NA H4',7400,'manual6',4.1,.313,10500,15.3),
('integra','Acura','Integra Type R',1997,'D',195,8000,176,7300,1160,'FWD','1.8L NA I4',8400,'manual5',4.4,.294,15000,14.9),
('gti','Volkswagen','Golf GTI',2012,'D',200,5100,281,1800,1375,'FWD','2.0L turbo I4',6800,'manual6',3.94,.318,12000,14.8),
('s2000','Honda','S2000',2004,'D',240,7800,220,6500,1285,'RWD','2.2L NA I4',8200,'manual6',4.1,.315,19000,14.1),
('gr86','Toyota','GR86',2022,'D',228,7000,249,3700,1276,'RWD','2.4L NA H4',7500,'manual6',4.1,.318,18000,14.0),
('z350','Nissan','350Z',2003,'D',287,6200,371,4800,1463,'RWD','3.5L NA V6',6600,'manual6',3.538,.326,15000,14.1),
('supra','Toyota','Supra Turbo',1998,'C',320,5600,427,4000,1565,'RWD','3.0L twin-turbo I6',6800,'manual6',3.133,.326,33000,13.1),
('m3','BMW','M3 E46',2001,'C',333,7900,355,4900,1549,'RWD','3.2L NA I6',8000,'manual6',3.62,.333,26000,13.3),
('sti','Subaru','WRX STI',2004,'C',300,6000,407,4000,1480,'AWD','2.5L turbo H4',7000,'manual6',3.9,.317,25000,13.3),
('evo','Mitsubishi','Lancer Evolution VIII',2003,'C',271,6500,370,3500,1470,'AWD','2.0L turbo I4',7000,'manual5',4.529,.317,24000,13.6),
('type_r','Honda','Civic Type R',2019,'C',306,6500,400,2500,1417,'FWD','2.0L turbo I4',7000,'manual6',4.111,.322,28000,13.5),
('mustang','Ford','Mustang GT',2024,'B',480,7150,563,4900,1741,'RWD','5.0L NA V8',7500,'auto10',3.55,.343,35000,12.2),
('supra_gr','Toyota','GR Supra 3.0',2020,'B',335,5000,495,1600,1539,'RWD','3.0L turbo I6',7000,'auto8',3.15,.330,36000,12.3),
('camaro','Chevrolet','Camaro SS',2016,'B',455,6000,617,4400,1671,'RWD','6.2L NA V8',6500,'auto8',2.77,.335,32000,12.3),
('golf_r','Volkswagen','Golf R',2019,'B',288,5400,380,1800,1515,'AWD','2.0L turbo I4',6800,'dct7',4.059,.318,30000,12.9),
('z400','Nissan','Z Performance',2023,'B',400,6400,475,1600,1604,'RWD','3.0L twin-turbo V6',6800,'auto9',3.133,.334,37000,12.3),
('z06','Chevrolet','Corvette Z06',2023,'A',670,8400,623,6300,1661,'RWD','5.5L NA V8',8600,'dct8',4.9,.355,85000,10.5),
('gtr','Nissan','GT-R NISMO',2020,'A',600,6800,652,3600,1752,'AWD','3.8L twin-turbo V6',7100,'dct6',3.7,.354,100000,10.8),
('r8','Audi','R8 V10 Performance',2020,'A',611,8000,580,6500,1670,'AWD','5.2L NA V10',8700,'dct7',3.59,.345,105000,10.8),
('gt500','Ford','Mustang Shelby GT500',2020,'A',760,7300,847,5000,1892,'RWD','5.2L supercharged V8',7500,'dct7',3.73,.355,75000,11.0),
('redeye','Dodge','Challenger SRT Hellcat Redeye',2019,'A',797,6300,959,4500,2050,'RWD','6.2L supercharged V8',6500,'auto8',2.62,.358,68000,11.1),
('turbo_s','Porsche','911 Turbo S',2021,'S',640,6750,800,2500,1640,'AWD','3.8L twin-turbo H6',7200,'dct8',3.02,.354,145000,10.1),
('mclaren','McLaren','765LT',2021,'S',755,7500,800,5500,1388,'RWD','4.0L twin-turbo V8',8500,'dct7',3.31,.344,190000,9.9),
('sf90','Ferrari','SF90 Stradale',2020,'S',769,7500,800,6000,1770,'AWD','4.0L hybrid twin-turbo V8',8000,'dct8',3.55,.351,240000,9.5),
('demon','Dodge','Challenger SRT Demon 170',2023,'S',1025,6500,1281,4200,1941,'RWD','6.2L supercharged V8 / E85',6500,'auto8',3.09,.373,115000,8.91),
('chiron','Bugatti','Chiron',2018,'S',1479,6700,1600,2000,1995,'AWD','8.0L quad-turbo W16',7100,'dct7',2.73,.363,500000,9.4)]
RATIOS={
'miata':[3.136,1.888,1.33,1,.814],'civic_si':[3.23,2.105,1.458,1.107,.848],'gti_vr6':[3.3,1.944,1.308,1.034,.838],
'rsx':[3.266,2.13,1.517,1.147,.921,.738],'brz':[3.626,2.188,1.541,1.213,1,.767],'integra':[3.23,2.105,1.458,1.034,.787],
'gti':[3.36,2.09,1.48,1.09,1.1,.91],'s2000':[3.133,2.045,1.481,1.161,.97,.81],'gr86':[3.626,2.188,1.541,1.213,1,.767],
'z350':[3.794,2.324,1.624,1.271,1,.794],'supra':[3.827,2.36,1.685,1.312,1,.793],'m3':[4.227,2.528,1.669,1.226,1,.828],
'sti':[3.636,2.375,1.761,1.346,.971,.756],'evo':[2.928,1.95,1.407,1.031,.72],'type_r':[3.625,2.115,1.529,1.125,.911,.735],
'mustang':[4.696,2.985,2.146,1.769,1.52,1.275,1,.854,.689,.636],'supra_gr':[5.25,3.36,2.172,1.72,1.316,1,.822,.64],
'camaro':[4.56,2.97,2.08,1.69,1.27,1,.85,.65],'golf_r':[3.19,2.75,1.9,1.04,.79,.86,.66],
'z400':[5.425,3.263,2.249,1.649,1.221,1,.862,.713,.597],'z06':[2.905,1.759,1.22,.878,.653,.508,.397,.329],
'gtr':[4.056,2.301,1.595,1.248,1.001,.796],'r8':[3.133,2.588,1.88,1.14,.898,.884,.653],
'gt500':[3.14,2.05,1.43,1.1,.86,.68,.56],'redeye':[4.714,3.143,2.106,1.667,1.285,1,.839,.667],
'turbo_s':[4.89,3.17,2.15,1.56,1.18,.94,.76,.61],'mclaren':[3.98,2.61,1.91,1.48,1.16,.91,.69],
'sf90':[3.08,2.19,1.63,1.29,1.03,.84,.69,.58],'demon':[4.714,3.143,2.106,1.667,1.285,1,.839,.667],
'chiron':[3.18,2.25,1.73,1.4,1.17,.99,.84]}
SOURCES=[
'https://www.miata.net/faq/First%2025%20Years/Pricing%20%26%20Specs%20-%20Model%20Year/Specifications/1990%20MX-5%20Miata%20Specifications.pdf',
'https://hondanews.com/en-US/releases/honda-civic-si-history',
'https://www.edmunds.com/volkswagen/gti/1997/features-specs/',
'https://acuranews.com/en-US/releases/release-213ecdccccb00457c01e65004c34c6a5-2003-acura-rsx-specifications',
'https://subarumedia.iconicweb.com/mediasite/specs/2013_SubaruBRZspecs.pdf',
'https://hondanews.com/en-US/releases/release-398aa72722c1c76a6c1681004c34c9a9-1997-acura-integra-type-r-powertrain',
'https://di-uploads-pod16.s3.us-east-1.amazonaws.com/emichvw/uploads/2018/09/2012GTI.pdf',
'https://hondanews.com/en-US/releases/release-edd28b30f52d7f29f285b3004c34c4b3-2004-honda-s2000-specifications',
'https://pressroom.toyota.com/toyota-announces-pricing-on-all-new-2022-gr86/',
'https://usa.nissannews.com/en-US/releases/2003-350z-press-kit',
'https://pressroom.toyota.com/supra-chronology/',
'https://www.edmunds.com/bmw/m3/2001/features-specs/',
'https://www.subaru.ca/WebPage.aspx?ArticleID=598&WebPageId=5013&WebSiteID=284',
'https://www.cars.com/research/mitsubishi-lancer_evolution-2003/',
'https://hondanews.com/en-US/honda-automobiles/releases/release-52ba9fce70874c8e990bb539b044d09a-2019-honda-civic-type-r-specifications-features',
'https://media.ford.com/content/dam/fordmedia/North%20America/US/2022/09/14/2024-mustang-technical-specifications.pdf',
'https://pressroom.toyota.com/2020-supra-product-supra/',
'https://static.nhtsa.gov/odi/tsbs/2015/MC-10137252-9999.pdf',
'https://newspress-vwusamedia.s3.amazonaws.com/documents%2Foriginal%2F8730-2019GolfRTechnicalSpecifications.pdf',
'https://usa.nissannews.com/en-US/releases/2023-nissan-z-press-kit',
'https://news.chevrolet.com/newsroom.detail.html/Pages/news/us/en/2021/oct/1026-corvette-z06.html',
'https://usa.nissannews.com/en-US/releases/2020-nissan-gt-r-press-kit',
'https://www.audi.com/en/the-audi-r8-until-2024-updated-dynamics-for-the-high-performance-sports-car-11734/engine-11738',
'https://www.motortrend.com/reviews/2020-ford-mustang-shelby-gt500-first-drive-review-photos-specs',
'https://stellcmsdev.iconinteract.com/newsrelease/22163/newsroom.do?id=567',
'https://newsroom.porsche.com/en_US/products/porsche-new-911-turbo-s-coupe-cabriolet-top-of-the-range-premiere-20122.html',
'https://investors.mclaren.com/~/media/Files/M/McLaren-Services/results-centre/2021/mclaren-h1-2021-results-presentation_vf.pdf',
'https://cdn.ferrari.com/cms/network/media/pdf/pr_ferrari_sf90_stradale_gbr.pdf',
'https://www.dodge.com/news/challenger-srt-demon-170-edition.html',
'https://newsroom.bugatti.com/en/about/technical-specifications']
out={}
for n,row in enumerate(ROWS):
 id,brand,name,year,group,hp,hr,nm,tr,mass,drive,engine,limit,kind,final,radius,price,et=row
 boost=.8 if 'turbo' in engine else 0
 supercharged='supercharged' in engine
 pressure=1.0 if supercharged else boost
 mult=1+pressure*(.68 if supercharged else .8)
 base=nm/mult
 # Anchors are reconstructed from the published peaks, not a measured dyno trace.
 anchor={850:nm*.34,1500:nm*(.56 if 'NA' in engine else .65),tr:nm,hr:hp*7127/hr,limit:min(nm*.78,hp*7127/limit*.94) if limit>hr else hp*7127/hr}
 if tr<2500: anchor[4500]=min(nm,hp*7127/4500*.98)
 points=[]
 for rpm,tq in sorted(anchor.items()):
  target=pressure if supercharged else boost*max(0,min(1,(rpm-1200)/2700))
  points.append([round((rpm-850)/(limit-850),6),round(tq/base/(1+target*(.68 if supercharged else .8)),6)])
 points.append([1.15,.15])
 out[id]=dict(id=id,name=f'{brand} {name}',display_name=f'{brand} {name}',brand=brand,model=name,year=str(year),requested_class=group,performance_class=group,
  factory_hp=986 if id=='sf90' else hp,ice_hp=hp,peak_rpm=hr,peak_torque_nm=nm,torque_rpm=tr,torque=base,mass=mass,drive=drive,engine=engine,cylinders=16 if id=='chiron' else 10 if id=='r8' else 8 if 'V8' in engine else 6 if any(s in engine for s in ['V6','I6','H6','VR6']) else 4,
  redline=limit,idle=850,base_boost=boost,factory_super=pressure if supercharged else 0,factory_trans='oem_'+id,gearbox_kind=kind,gear_ratios=RATIOS[id],final_drive=final,tire_radius=radius,
  grip=1.25 if id=='demon' else 1.0 if drive=='AWD' else .8 if group in 'AS' else .68,drag_area=.62 if group in 'AS' else .68,
  inertia=.18 if hp<250 else .26 if hp<600 else .35,price=price,unlock_level=max(1,'EDCBAS'.index(group)),torque_curve=points,
  hybrid_kw=162 if id=='sf90' else 0,hybrid_kwh=7.9 if id=='sf90' else 0,description='Factory-inspired configuration. Technical data and estimate status in Details.',
  wheelbase=[210,790],wheel_y=274,wheel_radius=70,source=SOURCES[n],reference_quarter_s=et,
  evidence={'rated_output':'published source; market/trim noted in report','mass_gearing_tires':'working figures; individual field verification pending','curve':'reconstructed from output peaks, not measured','grip_drag_inertia_efficiency':'simulation estimates','quarter_reference':'comparison target; provenance review pending except Demon manufacturer claim'},
  market='EU 620 PS' if id=='r8' else 'US; selected factory gearbox; Demon E85 full-power / prepared surface reference' if id=='demon' else 'US where available')
(ROOT/'assets/data').mkdir(exist_ok=True)
(ROOT/'assets/data/roster.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('Wrote',len(out),'factory-inspired specifications; unresolved field provenance explicitly retained')
if __name__=='__main__': pass
