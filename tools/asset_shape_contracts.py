"""Shared, noun-specific art instructions and schematic object silhouettes.

Rectangles describe placement capacity, never a universal object mesh.  This
module is used only by offline art forms; gameplay collision is independent.
"""
from __future__ import annotations
import math


SHAPES = {
 'bed': '床有薄床垫、床沿、床头／床尾和分开的床脚，床底留空；医用床保留金属架和轮脚，不是实心方台。',
 'stool': '圆形凳面在斜视下呈椭圆，分开的细凳腿之间透空，不把占地矩形画成凳面。',
 'chair': '靠背、坐面、支腿是不同层次，腿间与扶手下透空；靠背顺人体承托微弯，不是四方墩。',
 'chair_group': '每个座位分别可辨，有薄坐面、靠背和共用支架；座位间与下方透空，不画成整块长柜。',
 'fan': '圆形网罩包住少数扇叶，细立杆接圆形底座；网罩是圆盘轮廓，不能被尺寸框压成方盒。',
 'plant': '盆口为椭圆，花盆向下略收，枝叶以疏密不齐的大叶团伸出；花坛沿实际边界，不把植物画成方形绿块。',
 'tree': '树干向上分叉，枝条粗细递减、轮廓不对称，根部落地；不画成方柱或矩形树冠。',
 'table': '薄桌面承在分开的桌腿或原有中柱上，桌下可透视；圆台保留椭圆台面，弧形台保留凹弧工作侧。',
 'shelf': '薄层板、侧架和背板关系清楚，层格是实际开口；脚架和层板之间不填实。',
 'cabinet': '柜体可以有矩形大面，但门缝、拉手、板厚、底脚和真正的层格清楚；不是没有构造的灰色立方体。',
 'box': '箱子沿自身材质有薄壁、盖沿或折叠纸板，盖与箱身分层；纸箱、皮箱、塑料箱不套同一个正方体。',
 'rack': '细立杆、分叉挂钩与稳固分脚形成开放轮廓；挂衣／材料架按实际用途，不填成实心柜。',
 'cart': '上下薄托盘、连接杆、推手与轮子可辨，杆间和托盘下透空；物品另层，不画成带轮方柜。',
 'sofa': '软包靠背、扶手和坐垫有厚薄变化与承托弧度，底部有脚和阴隙，不是刚硬长方块。',
 'sink': '盆体有椭圆或圆角内腔、盆沿与排水口，龙头是独立弯管；有下柜时仍保留盆的凹面。',
 'toilet': '椭圆便池、座圈、后水箱与弯曲底座分明，保留真正内腔，不画成方箱。',
 'screen': '显示面、薄外壳、支架与底座分开；弧形屏保留横向弯曲，镜／屏面无自动生成文字。',
 'mirror': '薄镜面嵌入边框，必要支脚落地；镜是片状表面，不是厚实柜体，也不自动画第二个房间。',
 'core': '核心以完整的卵形、分叶或同心层叠大形构成，表面有缓慢起伏、收束与凹面；不是红色方块，不画血肉创面。',
 'cable': '纤维／管线是有直径的细长束，沿实际起终点弯曲、分流和收束，束间留缝；不是铺地长方块。',
 'clamp': '夹口有两片相对的弧形夹爪、转轴与中间开口；张合件可拆，闭合时尺寸允许实际接触，不是实心方块。',
 'node': '接驳节点是圆盘或卵形接头与少量放射接口，连接处有明确方向，支撑与线缆分开。',
 'rail': '栏杆由细立柱和连续横杆组成，栏下透空；弯井沿弧线布置，不能画成挡路实墙。',
 'bag': '袋体由柔软垂坠、收口和不对称鼓包构成，褶皱沿受力方向；不是硬箱。',
 'lamp': '细灯杆／弯臂、实际灯罩与底座分开；灯罩光面局部受光，光束和外扩辉光由游戏另加。',
 'board': '薄板、边框和必要支架分明，板面为空白；不用厚方箱代替，不在图内生成文字。',
 'fountain': '池沿形成可读的圆／椭圆或实际多边形环，池内凹下，雕像立在中心承台；水效独立，不画成实心长柜。',
 'statue': '雕像保留头、躯干与肢体的大轮廓，底座只承托脚下；不把人物雕像缩成一根方柱。',
 'folds': '完整表皮形成宽窄不一、起伏连续的折叶／脑回，折叶间有真实凹沟与通行空隙；不是规则积木阵列。',
 'organic': '沿现场用途形成完整的弧形、分叶与收束大形，表面连续，凸起和凹沟有疏密；避免方盒、密集血管和开放创面。',
 'platform': '平台是薄板或完整弧缘的低位支撑，有真实厚度和必要支点，台下留空；不可把周边可行走地面占满。',
 'mechanical_arm': '少量粗细分明的臂段通过圆形关节连接，末端执行器与底座独立，段间留空；不能画成整块方柱。',
 'frame': '开放框架由窄杆、拱部、支脚与真正的中间空隙构成，人体活动处透空，不画成封闭箱舱。',
 'recorder': '薄机壳前有两个清楚圆卷盘、带路和少量旋钮，支架细而独立；不是无结构方柜。',
 'vessel': '罐／胶囊为圆柱或两端收圆的长卵体，盖、颈口和接管分明，不能因尺寸参照变成长方柜。',
 'small': '保留本物件名称对应的真实薄厚、弧度、孔洞、握持处和材质；用原物结构塑形，不给小道具附加方盒外壳。',
 'door': '薄门扇有门框、板厚、铰接边和把手；开启绕真实铰链旋转，门洞留空，不把门画成厚方柱。',
 'window': '窗扇是薄边框与玻璃，尺度与既有固定框对位，窗台及窗下墙属于场景；不附加独立方柱、不把窗框立在墙顶。',
 'bin': '桶口为椭圆或圆角开口，桶身向底部略收，桶沿、内腔与盖分层；不能以实心箱替代。',
 'curtain': '轻薄帘面由顶轨悬挂，布料沿重力垂坠、底边略起伏；不是硬板或方形立柜。',
 'device': '保留本设备的薄壳、倾斜工作面、独立接头、按钮与必要支架，结构服务本处操作；不随意加厚成储物柜。',
 'rug': '织物贴地、有薄边和可掀角，图案以少量大色区处理；不是高起方台。',
 'debris': '几件大小与朝向不同的实际杂物组成低矮松散堆，轮廓有高低和空隙，不合并为整块方箱。',
}


def shape_family(item):
    name=str(item.get('name',''))+' '+str(item.get('id',''))+' '+str(item.get('silhouette_note',''))
    kind=str(item.get('kind',''))
    explicit=item.get('shape_family') or item.get('visual_shape')
    if explicit in SHAPES:return explicit
    if item.get('id')=='ENV_BED':return 'bed'
    tests=[
      ('door',['通用房门']),('window',['窗：']),('bin',['垃圾桶','污物桶']),('curtain',['隔帘']),('rug',['地毯']),('debris',['杂物堆']),
      ('fan',['风扇']),('stool',['圆凳','蓝凳']),('tree',['枯树']),
      ('fountain',['喷泉']),('statue',['雕像']),('mechanical_arm',['机械臂']),('frame',['姿态架','姿态测试架']),('recorder',['录音机','录音器','盘式记录']),
      ('clamp',['夹具','夹爪','触觉测试']),('core',['核心','记忆陈列']),
      ('vessel',['液罐','胶囊','测试舱']),('folds',['折叶','脑回墙']),
      ('organic',['异常组织','异化塌陷','粘连']),('cable',['纤维束','管道','管线','冷却管','导管']),
      ('rail',['栏杆','护栏','道闸']),('mirror',['镜']),('rack',['衣帽架','挂衣']),
      ('bed',['病床','转运床','检查床','单人床','转运推床','身体检查台']),('cart',['药盘车','清洁车','推车']),
      ('chair_group',['候诊椅','候诊长椅','等候长椅','座椅组','团体座椅']),
      ('sofa',['沙发']),('chair',['椅']),('plant',['绿植','花坛']),('sink',['洗手']),('toilet',['马桶']),
      ('lamp',['灯']),('screen',['显示屏','旧电视','弧形屏','叫号屏']),
      ('board',['白板','展示板','照片墙','指令板','路线板','标识板','示意板','记忆墙']),
      ('platform',['平台']),('shelf',['书架','药架','资料架','病历架','材料架','壁架']),
      ('table',['书桌','办公桌','活动桌','操作桌','会议桌','工作台','核验台','配药台','茶几','温控台','环形操作','弧形中继控制台','弧形情绪记录台','导诊台','护士站台']),
      ('node',['连接节点','连接器']),('statue',['肢体模型']),('chair',['警戒观察位']),
      ('device',['自助机','饮水机','打印机','控制台','数据终端','记录仪','检测器','门禁面板','检修面板','维护设备','压力阀组','加热器','航迹地图','时光装置','电子检查器']),
      ('board',['宣传架']),('bag',['袋']),('box',['木箱','纸箱','杂物箱','皮箱','收纳箱','纸盒','药盒']),
      ('cabinet',['柜']),
    ]
    for family,needles in tests:
        if any(n in name for n in needles):return family
    by_kind={'bed':'bed','drawer':'cabinet','wardrobe':'cabinet','cabinet':'cabinet','books':'shelf','material_rack':'shelf','shelf':'shelf','desk':'table','table':'table','counter':'table','console':'screen','screen':'screen','machine':'screen','chair':'chair','bench':'chair_group','chairs':'chair_group','stool':'stool','rack':'rack','plant':'plant','tree':'tree','fan':'fan','box':'box','cart':'cart','cleaner_cart':'cart','sofa':'sofa','sink':'sink','toilet':'toilet','mirror':'mirror','core':'core','node':'node','cable':'cable','clamp':'clamp','rail':'rail','lamp':'lamp','wall_lamp':'lamp','bag':'bag','board':'board','statue':'statue','fountain':'fountain','wall':'folds','groove':'organic','model':'statue','recorder':'recorder'}
    return by_kind.get(kind,'small')


def shape_instruction(item):
    family=shape_family(item)
    name=str(item.get('name',''))+' '+str(item.get('id',''))
    small=[
      (['眼镜'],'细镜框、中梁与两根镜腿完整，两片镜孔保持通透，不画成厚矩形块。'),
      (['项圈','腕带','束带'],'柔性带身形成有开口的环或弯带，扣、孔与搭接处可辨；不把环的内部填实。'),
      (['钥匙'],'钥匙柄有穿孔，细钥匙杆与齿分开；钥匙串各把能辨认，不并成方板。'),
      (['粥','药杯'],'碗／杯的口沿是椭圆，侧壁向底部收束，口内有实际内腔和内容面；无蒸汽光效。'),
      (['酒瓶','样本管','针具'],'细圆柱瓶／管身、缩颈或针筒与端口明确，玻璃有节制的透光；不套方盒。'),
      (['药片','糖果','巧克力'],'仅画本物实际的小圆片／糖纸包裹／薄巧克力块，保留尺度差异；不是放大方形家具。'),
      (['白褂','大褂','病服','衣物','床单','盖布','遮盖布'],'布料按悬挂、折叠或覆盖用途形成柔软外轮廓和少量大褶，袖口／领口／边缘层叠可辨；不填成硬块。'),
      (['鞋'],'鞋头圆钝、鞋帮收束、鞋底有薄厚，左右鞋分别可辨；内部鞋口留空。'),
      (['夹板','号码夹','纸页','文件纸','纸巾'],'主体为薄片叠层，纸角与夹扣关系清楚；开口或翻页沿原铰边，不长出抽屉柜门。'),
      (['印章'],'短握柄连接实际印座，握持与落印两端分明，不加生成文字。'),
      (['托盘'],'薄而浅的盘体、圆角盘沿和凹入盘底可辨；不是高方箱。'),
      (['纱布','敷料'],'薄织物折层与少量卷带，边缘柔软，不能画成厚柜或密集伤口。'),
      (['笔','教棍','指示棍'],'细长杆身，握端与尖端清楚，留足完整长度，不加方形外壳。'),
      (['胶带'],'短圆筒胶带卷，中间纸芯孔必须贯通，带头可见；不是实心圆饼。'),
      (['剪刀'],'两片细刀刃绕一个转轴，两只椭圆指环保持开孔，握柄与刀口区分。'),
      (['书／','书本'],'封面、书脊、薄页叠层分开；展开内页有弧度，保持空白，不能沿用抽屉打开结构。'),
      (['锤子'],'细木柄接短锤头，握柄与击面分开，无血污或光效。'),
      (['闹钟'],'圆或圆角表壳与薄表盘、指针和底脚分层，表面不生成数字。'),
      (['呼叫按钮'],'小底板上有明确凸起按键，线缆独立，保留手指可按的工作面。'),
      (['香烟'],'细圆柱烟身、滤嘴与端部区别清楚；不画烟雾、人物或方形盒。'),
      (['清洁工具'],'细长杆与软布头／刷头分开，工具支撑和握持位置清楚，不能合成方柜。'),
      (['录音线'],'细长软线沿轻弧弯曲，断端与接头分开，不画成硬矩形条。'),
      (['橡皮'],'小而薄的圆角橡皮块，边角略钝，保持文具尺度，不画成立方家具。'),
      (['直尺'],'薄而窄的长直尺，厚度远小于长度，刻度文字另加，不画成厚箱。'),
      (['搬运板'],'低薄承托板下有独立小轮与轮轴，板沿可握，板下透空；不是高柜。'),
    ]
    if family=='small':
        for needles,note in small:
            if any(n in name for n in needles):return family,note
    return family,SHAPES[family]


class ObjectSchematic:
    """Projected structural silhouette, in the renderer's existing metre basis."""
    def __init__(self,renderer,item,color=None):
        self.r=renderer;self.item=item;self.x,self.z,self.w,self.depth=item['rect'];self.h=max(.03,float(item.get('height_m',.8)))
        self.color=tuple(color or renderer.colors['prop']);self.dark=tuple(int(v*.63) for v in self.color[:3])+(255,)
        self.light=tuple(min(255,int(v*1.11)) for v in self.color[:3])+(255,)

    def pt(self,u,v,h):
        x=(u-.5)*self.w;z=(v-.5)*self.depth;a=float(self.item.get('schematic_angle',0))
        return self.r.p(self.x+self.w*.5+x*math.cos(a)+z*math.sin(a),self.z+self.depth*.5-x*math.sin(a)+z*math.cos(a),h*self.h)
    def line(self,points,width=.035,color=None):
        self.r.d.line([self.pt(*p) for p in points],fill=color or self.dark,width=max(2,round(width*self.r.hp*self.r.scale)),joint='curve')
    def panel(self,points,color=None):self.r.polygon([self.pt(*p) for p in points],color or self.color)
    def prism(self,ring,top,bottom=0):
        for i,(u,v) in enumerate(ring):
            a,b=ring[(i+1)%len(ring)];dx=(a-u)*self.w;dz=(b-v)*self.depth
            if dz*(-6)-dx*56>0:self.panel([(u,v,bottom),(a,b,bottom),(a,b,top),(u,v,top)],self.color)
        self.panel([(u,v,top) for u,v in ring],self.light)
    def cuboid(self,u,v,w,d,b,h,color=None):self.r.box([self.x+u*self.w,self.z+v*self.depth,w*self.w,d*self.depth],h*self.h,color or self.color,bottom=b*self.h)
    def ellipse(self,u,v,ru,rv,h,color=None):
        pts=[(u+math.cos(a)*ru,v+math.sin(a)*rv,h) for a in [i*math.tau/40 for i in range(40)]]
        self.panel(pts,color)
    def cylinder(self,u,v,ru,rv,b,h):
        pts=[(u+math.cos(a)*ru,v+math.sin(a)*rv,b) for a in [i*math.pi/24 for i in range(25)]]
        self.panel(pts+[(a,c,b+h) for a,c,_ in reversed(pts)],self.color)
        self.ellipse(u,v,ru,rv,b+h,self.light)
    def legs(self,top=.5,spread=.08):
        for u,v in [(.15,.15),(.85,.15),(.15,.85),(.85,.85)]:
            self.line([(u,v,top),(u+(-spread if u<.5 else spread),v,0)])
    def wheel(self,u,v,rad=.08):
        c=self.pt(u,v,.06);rx=max(3,self.w*self.r.x[0]*self.r.scale*rad);ry=rx*.8
        self.r.d.ellipse([c[0]-rx,c[1]-ry,c[0]+rx,c[1]+ry],fill=self.dark)
    def draw(self):
        f=shape_family(self.item)
        brief=str(self.item.get('name',''))+' '+str(self.item.get('silhouette_note',''))
        if f in ['table','platform']:
            self.legs(.9 if f=='table' else .7)
            if any(n in brief for n in ['U形','U型','U字']):
                ring=[(0,0),(1,0),(1,1),(.73,1),(.73,.34),(.27,.34),(.27,1),(0,1)]
                self.prism(ring,1,.9)
            elif any(n in brief for n in ['近圆','圆形','环形']):self.cylinder(.5,.5,.48,.48,.90,.08)
            elif any(n in brief for n in ['弧形','弯曲','内凹','U形']):
                top=[(u,.15+.13*math.sin(u*math.pi),.98) for u in [i/24 for i in range(25)]]
                top +=[(u,.88-.34*math.sin(u*math.pi),.98) for u in [1-i/24 for i in range(25)]]
                self.panel(top,self.light)
            else:self.cuboid(0,0,1,1,.9,.10)
        elif f=='stool':
            self.legs(.82,.02);self.cylinder(.5,.5,.47,.47,.82,.16)
        elif f in ['chair','chair_group']:
            count=max(2,min(5,round(self.w/.6))) if f=='chair_group' else 1
            for i in range(count):
                u=(i+.5)/count;half=.42/count
                for a,b in [(u-half,.2),(u+half,.2),(u-half,.8),(u+half,.8)]:self.line([(a,b,0),(a,b,.45)])
                self.panel([(u-half,.12,.48),(u+half,.12,.48),(u+half,.88,.48),(u-half,.88,.48)],self.light)
                self.panel([(u-half,.14,.52),(u+half,.14,.52),(u+half,.2,1),(u-half,.2,1)])
        elif f=='bed':
            self.legs(.30,.0);self.cuboid(.03,.02,.94,.96,.25,.14)
            self.cuboid(.02,.02,.96,.06,.28,.68)
            self.cuboid(.02,.92,.96,.06,.28,.28)
            self.cuboid(.14,.12,.72,.20,.4,.1,self.light)
        elif f=='fan':
            self.cylinder(.5,.53,.33,.33,0,.06);self.line([(.5,.53,.05),(.5,.53,.67)],.05)
            points=[(.5+math.cos(a)*.44,.5,.72+math.sin(a)*.27) for a in [i*math.tau/40 for i in range(41)]]
            self.panel(points,self.light)
            for ang in [0,math.tau/3,math.tau*2/3]:self.line([(.5,.49,.72),(.5+math.cos(ang)*.30,.49,.72+math.sin(ang)*.19)],.055)
        elif f in ['plant','tree']:
            if f=='plant':self.cylinder(.5,.55,.22,.22,0,.32)
            self.line([(.5,.5,.2),(.51,.47,.83)],.07)
            for u,v,h in [(.17,.3,.78),(.80,.35,.87),(.3,.7,.69),(.75,.68,.66),(.5,.48,.99)]:
                self.line([(.5,.5,.48),(u,v,h)],.027)
                if f=='plant':self.panel([(u-.14,v,h-.06),(u,v-.11,h+.05),(u+.16,v,h),(u,v+.12,h-.04)])
        elif f=='rack':
            self.line([(.5,.5,0),(.5,.5,1)],.055)
            for u,v in [(.1,.15),(.9,.15),(.1,.9),(.9,.9)]:self.line([(u,v,0),(.5,.5,.1)])
            for h in [.65,.88]:
                for u in [.16,.84]:self.line([(.5,.5,h-.1),(u,.5,h),(u,.5,h+.07)])
        elif f in ['cabinet','box']:
            self.cuboid(.03,.03,.94,.94,.05,.93)
            if f=='cabinet':
                self.line([(.5,1,.13),(.5,1,.91)],.015)
                for u in [.43,.57]:self.line([(u,1,.47),(u,1,.63)],.025)
            else:self.line([(.03,.03,.87),(.97,.03,.87),(.97,.97,.87)],.015)
        elif f in ['shelf','cart']:
            for u in [.05,.95]:
                for v in [.05,.95]:self.line([(u,v,.04),(u,v,1)],.04)
            levels=[.1,.5,.9] if f=='cart' else [.05,.28,.51,.74,.97]
            for h in levels:self.cuboid(0,0,1,1,h,.025)
            if f=='cart':
                for u in [.1,.9]:
                    for v in [.1,.9]:self.wheel(u,v)
        elif f in ['screen','mirror','board','device']:
            self.cuboid(.24,.32,.52,.42,0,.06)
            self.line([(.5,.55,.05),(.5,.55,.38)],.05)
            if any(n in brief for n in ['弧形','微弯','宽弧']):
                for i in range(24):
                    a=i/24;b=(i+1)/24;va=.22+.3*math.sin(a*math.pi);vb=.22+.3*math.sin(b*math.pi)
                    self.panel([(a,va,.4),(b,vb,.4),(b,vb,.97),(a,va,.97)],(174,192,189,255))
            else:
                self.panel([(.03,.32,.37),(.97,.32,.37),(.97,.32,1),(.03,.32,1)])
                self.panel([(.09,.31,.44),(.91,.31,.44),(.91,.31,.94),(.09,.31,.94)],(188,201,196,255))
            if f=='device':self.panel([(.03,.32,.4),(.97,.32,.4),(.85,.92,.3),(.15,.92,.3)],self.light)
        elif f=='sofa':
            self.legs(.15,0);self.cuboid(.04,.04,.92,.92,.1,.32)
            self.cuboid(.03,.02,.94,.2,.42,.56)
            for u in [0,.86]:self.cuboid(u,.18,.14,.78,.35,.35)
        elif f=='folds':
            for i in range(5):
                u=.08+i*.2;thickness=min(.09/max(.01,self.w),.04)
                ring=[(u+.045*math.sin(t*math.pi),.06+.88*t) for t in [j/12 for j in range(13)]]
                ring +=[(u+thickness+.045*math.sin(t*math.pi),.06+.88*t) for t in [1-j/12 for j in range(13)]]
                self.prism(ring,.88+.12*math.sin(i))
        elif f in ['core','organic']:
            lobes=3
            for i in range(lobes):
                u=.25+i*.5/max(1,lobes-1)
                high=.70+.25*math.sin((i+1)*1.7)
                for step in range(17):
                    t=step/17;radius=math.sqrt(1-t*t);tone=tuple(min(255,round(v*(.86+t*.23))) for v in self.color[:3])+(255,)
                    self.ellipse(u,.5,.24*radius,.44*radius,high*t,tone)
        elif f in ['cable','rail']:
            if f=='cable':
                for offset in [-.14,0,.14]:self.line([(i/20,.5+offset+math.sin(i*.2)*.15,.18+math.sin(i*.16)*.10) for i in range(21)],.07)
            else:
                if self.w>=self.depth:
                    for u in [.04,.32,.66,.96]:self.line([(u,.5,0),(u,.5,.95)],.035)
                    self.line([(.02,.5,.9),(.98,.5,.9)],.045);self.line([(.02,.5,.45),(.98,.5,.45)],.025)
                else:
                    for v in [.04,.32,.66,.96]:self.line([(.5,v,0),(.5,v,.95)],.035)
                    self.line([(.5,.02,.9),(.5,.98,.9)],.045);self.line([(.5,.02,.45),(.5,.98,.45)],.025)
        elif f=='clamp':
            self.cylinder(.5,.5,.2,.2,0,.18)
            for sign in [-1,1]:self.line([(.5+sign*.1,.5,.15),(.5+sign*.38,.5,.55),(.5+sign*.18,.5,.94)],.10)
        elif f in ['sink','toilet','fountain','node','vessel','bin']:
            if f=='vessel':
                self.cylinder(.5,.5,.4,.4,.1,.78);self.cylinder(.5,.5,.2,.2,.88,.1)
            else:
                self.cylinder(.5,.5,.42,.42,.12,.36 if f=='fountain' else .6)
                self.ellipse(.5,.5,.33,.33,.49 if f=='fountain' else .73,(83,105,109,255))
                if f=='sink':self.line([(.6,.16,.73),(.6,.16,1),(.6,.42,1)],.04)
                elif f=='toilet':self.cuboid(.20,.03,.60,.19,.36,.63)
                elif f=='fountain':self.cylinder(.5,.5,.1,.1,.5,.42)
                elif f=='node':
                    for u,v in [(0,.5),(1,.5),(.5,0),(.5,1)]:self.line([(.5,.5,.4),(u,v,.15)],.08)
        elif f in ['door','window']:
            for u in [.05,.95]:self.line([(u,.5,0),(u,.5,1)],.045)
            for h in [0,1]:self.line([(.05,.5,h),(.95,.5,h)],.045)
            if f=='door':
                self.panel([(.09,.5,.03),(.91,.5,.03),(.91,.5,.96),(.09,.5,.96)])
                self.line([(.8,.51,.5),(.89,.51,.5)],.03)
            else:self.line([(.5,.5,0),(.5,.5,1)],.025)
        elif f=='curtain':
            self.line([(0,.5,1),(1,.5,1)],.035)
            for i in range(12):
                u=i/12;v=(i+1)/12;self.panel([(u,.5,.06+math.sin(i)*.025),(v,.5,.06+math.sin(i+1)*.025),(v,.5,1),(u,.5,1)],self.light if i%2 else self.color)
        elif f=='rug':
            self.panel([(.02,.02,.01),(.98,.02,.01),(.98,.98,.01),(.02,.98,.01)],self.color)
            self.panel([(.02,.98,.01),(.16,.87,.12),(.21,.98,.01)],self.light)
        elif f=='debris':
            for u,v,w,d,h in [(.03,.08,.32,.28,.38),(.48,.15,.39,.35,.67),(.13,.60,.46,.33,.24),(.69,.70,.25,.26,.43)]:self.cuboid(u,v,w,d,0,h)
        elif f=='mechanical_arm':
            self.cylinder(.3,.6,.25,.25,0,.12)
            self.line([(.3,.6,.12),(.2,.5,.60),(.65,.45,.85),(.9,.5,.65)],.10)
            for u,v,h in [(.2,.5,.6),(.65,.45,.85)]:self.cylinder(u,v,.1,.1,h-.05,.1)
        elif f=='frame':
            self.line([(.1,.5,0),(.1,.5,.82),(.25,.5,.98),(.75,.5,.98),(.9,.5,.82),(.9,.5,0)],.045)
            for u in [.1,.9]:self.line([(u,.1,0),(u,.9,0)],.045)
        elif f=='recorder':
            self.cuboid(.06,.2,.88,.6,.08,.72)
            for u in [.28,.72]:
                pts=[(u+.19*math.cos(a),.82,.55+.19*math.sin(a)) for a in [i*math.tau/32 for i in range(32)]]
                self.panel(pts,self.light)
        elif f=='lamp':
            self.cylinder(.5,.5,.2,.2,0,.05);self.line([(.5,.5,.05),(.5,.5,.87)],.035)
            self.panel([(.20,.5,.80),(.35,.5,1),(.65,.5,1),(.8,.5,.8)],self.light)
        elif f=='bag':
            self.panel([(.2,.1,.05),(.8,.1,.05),(.98,.7,.25),(.76,.93,.70),(.54,.64,1),(.4,.72,.92),(.12,.7,.48)])
        elif f=='statue':
            self.cuboid(.2,.15,.6,.7,0,.12);self.line([(.45,.48,.12),(.5,.48,.75)],.18)
            self.line([(.2,.5,.4),(.5,.5,.67),(.8,.5,.52)],.07);self.cylinder(.5,.5,.13,.13,.78,.20)
        else:
            # Unknown small objects get a low, neutral contour, not a full-height
            # fake cube. The object's written construction remains authoritative.
            self.panel([(.05,.15,.08),(.77,.05,.06),(.98,.74,.10),(.22,.96,.07)],self.light)
        return f


def draw_object(renderer,item,color=None):
    if shape_family(item)=='chair_group' and len(item.get('collision_rects',[]))>1:
        x,z,w,d=item['rect'];middle=(x+w*.5,z+d*.5)
        round_group='环' in str(item.get('silhouette_note','')) or bool(item.get('seat_positions_m'))
        for index,rect in enumerate(item['collision_rects']):
            seat={**item,'id':str(item.get('id','seats'))+':seat'+str(index),'kind':'chair','name':'独立座椅','silhouette_note':'','shape_family':'chair','rect':rect}
            if round_group:seat['schematic_angle']=math.atan2(middle[0]-rect[0]-rect[2]*.5,middle[1]-rect[1]-rect[3]*.5)
            ObjectSchematic(renderer,seat,color).draw()
        return 'chair_group'
    if shape_family(item)=='table' and len(item.get('collision_rects',[]))>1:
        for index,rect in enumerate(item['collision_rects']):
            segment={**item,'id':str(item.get('id','counter'))+':bar'+str(index),'name':'薄台面与支腿','silhouette_note':'','shape_family':'table','rect':rect}
            ObjectSchematic(renderer,segment,color).draw()
        return 'table'
    return ObjectSchematic(renderer,item,color).draw()


def spatial_description(room):
    spec=room.get('space_spec',{})
    parts=[]
    for key in ['shape_description','space_shape','shape_brief','topology_brief','architectural_brief','material_brief']:
        value=spec.get(key)
        if value:parts.append(str(value))
    if not parts:
        outline=spec.get('floor_polygon_m',[])
        if len(outline)>4:parts.append('地面沿定位图中的实际多边形、曲折或弧形边界展开；可行走的凸出、凹入和收束均保留，不用一个包围矩形补平。')
        if room.get('chapter') in [4,5]:parts.append('本关是脑皮层／白质／深部的功能空间；有机边界、沟回与通路按本房定位，不移植卧室四面直墙。')
    holes=spec.get('floor_holes_m',[])
    if holes:parts.append('地面内有'+str(len(holes))+'处真实不可通行的沟井／空洞，位置与边界沿定位图保留；不可用同色地板铺满，也不可跨越。')
    return '\n'.join(dict.fromkeys(parts))
