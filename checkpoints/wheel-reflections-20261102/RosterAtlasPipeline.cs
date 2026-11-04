using System;using System.IO;using System.Drawing;using System.Drawing.Imaging;using System.Drawing.Drawing2D;using System.Runtime.InteropServices;using System.Collections.Generic;
class AtlasPipeline{
static byte[] Read(Bitmap b){var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);byte[] p=new byte[d.Stride*b.Height];Marshal.Copy(d.Scan0,p,0,p.Length);b.UnlockBits(d);return p;}
static void Save(byte[] p,string path){using(var b=new Bitmap(1000,360,PixelFormat.Format32bppArgb)){var d=b.LockBits(new Rectangle(0,0,1000,360),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);Marshal.Copy(p,0,d.Scan0,p.Length);b.UnlockBits(d);b.Save(path,ImageFormat.Png);}}
static int Alpha(byte[] p,int w,int h,int x,int y){return x<0||y<0||x>=w||y>=h?0:p[(y*w+x)*4+3];}
static double Lum(byte[] p,int w,int h,int x,int y){if(x<0||y<0||x>=w||y>=h)return 255;int i=(y*w+x)*4;return(p[i]+p[i+1]+p[i+2])/3.0;}
static int[] Wheel(byte[] p,int w,int h,int bottom,bool front){double best=-1e20;int[] found=null;
for(int x=front?690:170;x<(front?870:330);x+=2)for(int r=53;r<=90;r+=2)for(int y=bottom-96;y<=bottom-48;y+=2){double score=0;
for(int k=1;k<18;k++){double t=Math.PI*k/18;int xi=x+(int)((r-4)*Math.Cos(t)),yi=y+(int)((r-4)*Math.Sin(t));int xo=x+(int)((r+5)*Math.Cos(t)),yo=y+(int)((r+5)*Math.Sin(t));score+=Alpha(p,w,h,xi,yi)-Alpha(p,w,h,xo,yo)-Lum(p,w,h,xi,yi)*.8;}
if(score>best){best=score;found=new[]{x,y,r};}}return found;}
static void Main(string[] a){string root=a[0];string[] groups={"E","D","C","B","A","S"};
string[][] ids={new[]{"miata","civic_si","gti_vr6","rsx","brz"},new[]{"integra","gti","s2000","gr86","z350"},new[]{"supra","m3","sti","evo","type_r"},new[]{"mustang","supra_gr","camaro","golf_r","z400"},new[]{"z06","gtr","r8","gt500","redeye"},new[]{"turbo_s","mclaren","sf90","demon","chiron"}};
int[][] colors={new[]{243,105,64},new[]{159,189,179},new[]{222,214,186},new[]{104,126,175},new[]{208,168,59},new[]{172,115,158}};
var meta=new List<string>();meta.Add("id,rear_x,front_x,wheel_y,radius,top,bottom,scale");
for(int group=0;group<6;group++)using(var original=new Bitmap(Path.Combine(root,"assets/vehicles/source_atlases",groups[group]+".png"))){var p=Read(original);int w=original.Width,h=original.Height;
var bands=new List<int[]>();int start=-1,gap=0,last=0;
for(int y=0;y<h;y++){int count=0;for(int x=0;x<w;x++)if(Alpha(p,w,h,x,y)>220)count++;if(count>14){if(start<0)start=y;gap=0;last=y;}else if(start>=0&&++gap>8){bands.Add(new[]{start,last});start=-1;}}
if(start>=0)bands.Add(new[]{start,last}); int[][] cuts={new[]{0,325,655,990,1300,1536},new[]{0,330,685,980,1265,1536},new[]{0,325,645,970,1280,1536},new[]{0,330,650,965,1285,1536},new[]{0,325,655,970,1280,1536},new[]{0,340,655,960,1275,1536}}; bands.Clear(); for(int slot=0;slot<5;slot++){int lo=cuts[group][slot],hi=cuts[group][slot+1]-1; while(lo<hi){int count=0;for(int x=0;x<w;x++)if(Alpha(p,w,h,x,lo)>220)count++;if(count>14)break;lo++;}while(hi>lo){int count=0;for(int x=0;x<w;x++)if(Alpha(p,w,h,x,hi)>220)count++;if(count>14)break;hi--;}bands.Add(new[]{lo,hi});}
for(int row=0;row<5;row++){string id=ids[group][row],folder=Path.Combine(root,"assets/vehicles",id);Directory.CreateDirectory(folder);int top=bands[row][0],bottom=bands[row][1];int[] rear=Wheel(p,w,h,bottom,false),front=Wheel(p,w,h,bottom,true);
int left=w,right=0;for(int y=top;y<=bottom;y++)for(int x=0;x<w;x++)if(Alpha(p,w,h,x,y)>220){left=Math.Min(left,x);right=Math.Max(right,x);}
double scale=Math.Min(920.0/(right-left+1),300.0/(bottom-top+1)),cy=(rear[1]+front[1])/2.0,ox=40-left*scale,oy=274-cy*scale;
int rx=(int)Math.Round(ox+rear[0]*scale),fx=(int)Math.Round(ox+front[0]*scale),radius=(int)Math.Round((rear[2]+front[2])*.5*scale);
byte[] pixels;using(var b=new Bitmap(1000,360,PixelFormat.Format32bppArgb)){using(var g=Graphics.FromImage(b)){g.CompositingMode=CompositingMode.SourceCopy;g.InterpolationMode=InterpolationMode.HighQualityBicubic;g.DrawImage(original,new RectangleF((float)ox,(float)(oy+top*scale),(float)(w*scale),(float)((bottom-top+1)*scale)),new RectangleF(0,top,w,bottom-top+1),GraphicsUnit.Pixel);}pixels=Read(b);}
for(int wheelIndex=0;wheelIndex<2;wheelIndex++){int center=wheelIndex==0?rx:fx;using(var wheelArt=new Bitmap(radius*2+4,radius*2+4,PixelFormat.Format32bppArgb)){for(int wy=-radius;wy<=radius;wy++)for(int wx=-radius;wx<=radius;wx++){int px=center+wx,py=274+wy;if(wx*wx+wy*wy>radius*radius||px<0||px>=1000||py<0||py>=360)continue;int at=(py*1000+px)*4;wheelArt.SetPixel(wx+radius+2,wy+radius+2,Color.FromArgb(pixels[at+3],pixels[at+2],pixels[at+1],pixels[at]));}wheelArt.Save(Path.Combine(folder,wheelIndex==0?"rear_wheel.png":"front_wheel.png"),ImageFormat.Png);}} byte[] mask=new byte[pixels.Length],glass=new byte[pixels.Length],lamps=new byte[pixels.Length];
for(int y=0;y<360;y++)for(int x=0;x<1000;x++){int i=(y*1000+x)*4;bool wheel=(x-rx)*(x-rx)+(y-274)*(y-274)<(radius+1)*(radius+1)||(x-fx)*(x-fx)+(y-274)*(y-274)<(radius+1)*(radius+1);
if(pixels[i+3]<240||wheel){pixels[i]=0;pixels[i+1]=0;pixels[i+2]=0;pixels[i+3]=0;continue;}pixels[i+3]=255;double v=Math.Max(pixels[i],Math.Max(pixels[i+1],pixels[i+2])),m=Math.Min(pixels[i],Math.Min(pixels[i+1],pixels[i+2]));
bool glazing=x>220&&x<730&&y<185&&y>35&&v<105, lamp=(x<135||x>865)&&v-m>40&&y>130&&y<265;
if(glazing){Array.Copy(pixels,i,glass,i,4);continue;}if(lamp){Array.Copy(pixels,i,lamps,i,4);continue;}if(v>8&&v-m<55){mask[i]=255;mask[i+1]=255;mask[i+2]=255;mask[i+3]=255;}}
byte[] tint=(byte[])glass.Clone(),stripe=new byte[pixels.Length],empty=new byte[pixels.Length]; for(int i=0;i<tint.Length;i+=4){tint[i]=3;tint[i+1]=7;tint[i+2]=12;if(mask[i+3]>0&&i/4000>224&&i/4000<236){stripe[i]=225;stripe[i+1]=233;stripe[i+2]=235;stripe[i+3]=255;}} Save(tint,Path.Combine(folder,"tint.png"));Save(stripe,Path.Combine(folder,"stripe.png"));Save(empty,Path.Combine(folder,"spoiler.png")); Save(mask,Path.Combine(folder,"paint_mask.png"));Save(glass,Path.Combine(folder,"glass.png"));Save(lamps,Path.Combine(folder,"lamps.png"));
for(int paint=0;paint<6;paint++)for(int finish=0;finish<3;finish++){byte[] body=(byte[])pixels.Clone();
for(int i=0;i<body.Length;i+=4)if(mask[i+3]>0){double l=(pixels[i]+pixels[i+1]+pixels[i+2])/765.0,v=finish==1?.18+l*.68:l,shine=finish==1?0:Math.Max(0,(l-.76)/.24)*.65;
for(int channel=0;channel<3;channel++)body[i+channel]=(byte)Math.Min(255,255*v*(colors[paint][2-channel]/180.0)*(1-shine)+pixels[i+channel]*shine);}
Save(body,Path.Combine(folder,"body_"+paint+"_"+new[]{"gloss","matte","metallic"}[finish]+".png"));}
meta.Add(string.Join(",",new object[]{id,rx,fx,274,radius,top,bottom,scale.ToString(System.Globalization.CultureInfo.InvariantCulture)}));Console.WriteLine(id+": "+rx+" / "+fx+" radius "+radius);
}}File.WriteAllLines(Path.Combine(root,"assets/vehicles/atlas_geometry.csv"),meta);
}}



