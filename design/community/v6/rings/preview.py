import sys
from PIL import Image
S=sys.argv[1]
row=Image.open('cameragr/Resources/sleeve_row.jpg').convert('RGBA')  # 1300x299, hole at ~(40,150)
piece=Image.open(S+'/ring_piece.png')   # 700x270; seat centre (128,132), hole centre (605,132)
rail=Image.open(S+'/rail_plain.png')
# ring-piece scale so its hole rim (r~80) covers the sleeve hole (r~24)
k=26/80; piece=piece.resize((int(700*k),int(270*k)),Image.LANCZOS)
seatx,holex=128*k,605*k
rows=4; gap=6; RW,RH=row.size
railw=round(248*k); railx=40
holeX=railx+railw//2+int(holex-seatx)  # where the sleeve's hole must be
offx=holeX-40
W=offx+RW+20; Hh=rows*(RH+gap)+60
bg=Image.new('RGBA',(W,Hh),(32,28,24,255))
rail=rail.resize((railw,Hh-20),Image.LANCZOS); bg.alpha_composite(rail,(railx,10))
for i in range(rows):
    y=30+i*(RH+gap); bg.alpha_composite(row,(offx,y))
    cy=y+150
    bg.alpha_composite(piece,(int(railx+railw/2-seatx),int(cy-132*k)))
bg.convert('RGB').save(S+'/ring_preview.jpg',quality=88)
bg.crop((0,0,600,Hh)).convert('RGB').save(S+'/ring_preview_zoom.jpg',quality=90)
