"""Code-native skeleton references, not character art or runtime animation."""
from math import sqrt
from html import escape

PHASES={
 'left_contact':(.34,0,-.29,.035,0,'左脚前接触'),
 'right_contact':(-.29,.035,.34,0,0,'右脚前接触'),
 'left_passing':(-.02,0,.08,.16,.005,'左腿支撑、右脚经过'),
 'right_passing':(.08,.16,-.02,0,.005,'右腿支撑、左脚经过'),
 'left_down':(.24,0,-.16,.075,-.045,'左腿承重下沉'),
 'left_up':(-.20,.025,.27,.15,.025,'左脚蹬地、右腿前摆'),
 'right_down':(-.16,.075,.24,0,-.045,'右腿承重下沉'),
 'right_up':(.27,.15,-.20,.025,.025,'右脚蹬地、左腿前摆'),
}

def phase_key(p):
 text=p['label']+' '+p.get('text','')
 side='left' if '左' in p['label'] else 'right'
 if '下沉' in p['label']:return side+'_down'
 if any(t in p['label'] for t in ['蹬','升起']):return side+'_up'
 if '经过' in p['label']:return side+'_passing'
 if '接触' in p['label'] or '落地' in p['label']:return side+'_contact'
 raise ValueError('Unmapped walk pose: '+text)

def svg_guide(direction,phase):
 lu,lh,ru,rh,lift,label=PHASES[phase]
 t=[(1,0),(0,-1),(-1,0),(0,1)][direction];left=(t[1],-t[0])
 def world(u,l,h):return (t[0]*u+left[0]*l,h,t[1]*u+left[1]*l)
 def point(p):x,h,z=p;return (450+200*x+100/3*z,660-12.5*x+350/3*z-260*h)
 def pt(p):return '%.1f,%.1f'%point(p)
 def ik(hu,hh,fu,fh,lateral,a,b):
  du,dh=fu-hu,fh-hh;dist=sqrt(du*du+dh*dh);d=min(dist,a+b-.001)
  q=(a*a-b*b+d*d)/(2*d);height=sqrt(max(0,a*a-q*q));ux,uy=du/dist,dh/dist
  return world(hu+ux*q-uy*height,lateral,hh+uy*q+ux*height)
 def line(points,color,width=12,dash=''):
  return '<polyline points="'+' '.join(pt(p) for p in points)+'" fill="none" stroke="'+color+'" stroke-width="'+str(width)+'" stroke-linecap="round" stroke-linejoin="round"'+(' stroke-dasharray="'+dash+'"' if dash else '')+'/>'
 def circle(p,r,color,fill='white'):x,y=point(p);return f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" stroke="{color}" stroke-width="4" fill="{fill}"/>'
 hiph=.90+lift;body=[world(.01,0,hiph),world(.035,0,1.36+lift),world(.04,0,1.51+lift)]
 limbs=[]
 for sign,u,fh,color in [(1,lu,lh,'#b46d38'),(-1,ru,rh,'#3b7096')]:
  lateral=.105*sign;hip=world(.01,lateral,hiph);foot=world(u,lateral,fh);knee=ik(.01,hiph,u,fh,lateral,.49,.49)
  sh=world(.035,.18*sign,1.36+lift);handu=-.62*u;handh=1.01+lift;hand=world(handu,.18*sign,handh);elbow=ik(.035,1.36+lift,handu,handh,.18*sign,.29,.29)
  toe_h,heel_h=max(0,fh-.015),fh+.015
  active=('left' if sign==1 else 'right')
  if phase==active+'_contact':toe_h,heel_h=.035,0
  elif phase.endswith('_contact'):toe_h,heel_h=0,.065
  elif phase==active+'_up':toe_h,heel_h=0,.075
  toe=world(u+.13,lateral,toe_h);heel=world(u-.075,lateral,heel_h)
  limbs.append((-(left[0]*lateral)+left[1]*lateral,line([hip,knee,foot],color)+line([heel,toe],color,13)+line([sh,elbow,hand],color,10)+''.join(circle(p,6,color)for p in[hip,knee,foot,sh,elbow,hand])))
 x0,y0=point(world(-.60,0,0));x1,y1=point(world(.60,0,0))
 arrow_start=(750,140);dx,dy=(t[0]*200+t[1]*100/3,-t[0]*12.5+t[1]*350/3)
 norm=sqrt(dx*dx+dy*dy);ax,ay=arrow_start;bx,by=ax+dx/norm*70,ay+dy/norm*70
 content=f'<line x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" stroke="#adb5af" stroke-width="2" stroke-dasharray="6 6"/>'
 content+=''.join(v for _,v in sorted(limbs))+line(body,'#485a50',15)+line([world(.01,.105,hiph),world(.01,-.105,hiph)],'#485a50',12)+line([world(.035,.18,1.36+lift),world(.035,-.18,1.36+lift)],'#485a50',12)+circle(world(.04,0,1.65+lift),27,'#485a50','#f6f3e9')
 content+=f'<circle cx="450" cy="660" r="7" fill="#485a50"/><line x1="{ax}" y1="{ay}" x2="{bx:.1f}" y2="{by:.1f}" stroke="#485a50" stroke-width="4" marker-end="url(#arrow)"/>'
 title=f'D{direction} · {label}'
 return f'''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="800" viewBox="0 0 900 800"><defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L0,6 L7,3 z" fill="#485a50"/></marker></defs><rect width="900" height="800" fill="#faf8f1"/><g font-family="Microsoft YaHei,Arial,sans-serif" fill="#283d32"><text x="34" y="48" font-size="26">{escape(title)}</text><text x="34" y="82" font-size="18">姿态定位参照 · 只约束承重与手脚关系，不是人物造型</text><text x="34" y="125" font-size="19" fill="#b46d38">橙色＝角色自身左侧</text><text x="34" y="157" font-size="19" fill="#3b7096">蓝色＝角色自身右侧</text><text x="710" y="106" font-size="17">实际移动方向</text>{content}<text x="34" y="727" font-size="18">根基准固定；支撑脚相对身体后移，头与骨盆允许自然起伏。</text><text x="34" y="759" font-size="18">图1锁身份衣装；本图锁当前动作。手指、衣褶与细部沿人物母图。</text></g></svg>'''
