import sys, numpy as np
from PIL import Image, ImageDraw, ImageFilter
mod=np.array(Image.open(sys.argv[1]).convert('RGB')).astype(int)
rail=np.array(Image.open(sys.argv[2]).convert('RGB')).astype(int)
def key(a):
    r,g,b=a[...,0],a[...,1],a[...,2]
    return ~((g>120)&(g-r>40)&(g-b>40))
def despill(a):
    a=a.copy(); a[...,1]=np.minimum(a[...,1],np.maximum(a[...,0],a[...,2])); return a
H,W,_=mod.shape
yy,xx=np.mgrid[:H,:W]
fg=key(mod)
r,g,b=mod[...,0],mod[...,1],mod[...,2]
brass=(r-b>55)&(r>90)&(fg)
ringzone=(xx>380)&(xx<1000)&(yy>360)&(yy<620)
# keep only the brass blob connected to the seat (drops the vinyl stitching)
base=brass&ringzone
seed=np.zeros_like(base); seed[400:430,690:710]=True; seed&=base
ring=seed
for _ in range(400):
    d=ring.copy(); d[1:]|=ring[:-1]; d[:-1]|=ring[1:]; d[:,1:]|=ring[:,:-1]; d[:,:-1]|=ring[:,1:]
    d&=base
    if (d==ring).all(): break
    ring=d
for _ in range(7):
    d=ring.copy(); d[1:]|=ring[:-1]; d[:-1]|=ring[1:]; d[:,1:]|=ring[:,:-1]; d[:,:-1]|=ring[:,1:]
    ring=d&fg&(((mod.sum(-1)>330)&(xx<765))|brass)&ringzone
seat=((xx-458)**2+(yy-522)**2)<88**2
hole=((xx-935)**2+(yy-522)**2)<64**2
m=fg&(seat|hole|ring)
m=Image.fromarray((m*255).astype('uint8')).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
piece=Image.fromarray(despill(mod).astype('uint8')).convert('RGBA'); piece.putalpha(m)
piece.crop((330,390,1030,660)).save(sys.argv[3])
ra=Image.fromarray((key(rail)*255).astype('uint8')).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1))
rp=Image.fromarray(despill(rail).astype('uint8')).convert('RGBA'); rp.putalpha(ra)
rp.crop(rp.getbbox()).save(sys.argv[4])
