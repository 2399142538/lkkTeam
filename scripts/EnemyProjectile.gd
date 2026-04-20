extends Area2D


@export var speed := 360.0
@export var damage := 1
@export var lifetime := 2.4

const PROJECTILE_TEXTS := [
	"已读乱回一下",
	"你礼貌吗家人",
	"我真的会谢",
	"这波属实栓Q",
	"退退退别靠近",
	"当场破防了",
	"蚌埠住了属于是",
	"尊嘟假嘟啊",
	"建议你先听劝",
	"直接上强度",
	"你先别急嘛",
	"我真绷不住",
	"这局赢麻了",
	"开始原地开摆",
	"被你狠狠拿捏",
	"主打一个搞心态",
	"啊对对对对",
	"这就有内味了",
	"真下头警告",
	"小丑竟是我自己",
	"我服了呀",
	"泪目了兄弟",
	"笑死根本停不下",
	"好家伙来真的",
	"不愧是你啊",
	"细说我爱听",
	"速通我的防线",
	"别送了求你",
	"稳住我们能赢",
	"起猛了看见弹幕",
	"太抽象了吧",
	"这操作很逆天",
	"狠狠爆金币",
	"难绷但合理",
	"好耶冲就完了",
	"坏了冲我来的",
	"有点东西啊",
	"阁下何故如此",
	"请开始你的表演",
	"我不到啊真不到",
	"真香警告来了",
	"这合理吗请问",
	"你说得对但是",
	"先质疑再质疑",
	"撤回让我来说",
	"别尬黑真能打",
	"别太荒谬了",
	"大可不必如此",
	"问题不大能打",
	"问题很大快跑",
	"开始整活了",
	"有被笑到谢谢",
	"有被冒犯到",
	"我选择直接寄",
	"不许摆烂啊",
	"提前开香槟",
	"坐等一个反转",
	"这波其实不亏",
	"这波属实血亏",
	"一眼看穿了",
	"压力给到你这边",
	"没绷住兄弟",
	"太典了太典了",
	"建议原地重开",
	"优势在我这边",
	"优势突然不在",
	"这也行的吗",
	"啊这怎么说",
	"讲道理没道理",
	"别搞我心态",
	"别演了求求",
	"救一下能救",
	"我先跑为敬",
	"你来真的啊",
	"这波有操作",
	"无所谓我会出手",
	"打扰了告辞",
	"太难了别追",
	"先溜一步了",
	"这谁顶得住啊",
	"别刀了孩子",
	"我悟了大彻大悟",
	"懂的都懂别问",
	"问就是先寄",
	"主打一个陪伴",
	"提供情绪价值",
	"功德直接加一",
	"别卷了快睡",
	"今天也要发疯",
	"电子榨菜来了",
	"互联网嘴替",
	"沉默震耳欲聋",
	"我有一个朋友",
	"怎么个事儿",
	"你品你细品",
	"破大防现场",
	"这届网友不行",
	"给我整不会了",
	"属于是被拿下",
	"狠狠共情了"
]

var direction := Vector2.RIGHT
var trail_timer := 0.0

@onready var visual_label: Label = $Visual


func _ready() -> void:
	add_to_group("enemy_projectiles")
	visual_label.text = PROJECTILE_TEXTS[randi() % PROJECTILE_TEXTS.size()]
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	rotation = direction.angle()
	_keep_text_readable()
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.03
		queue_redraw()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.5, 0.16, 0.12))
	draw_circle(Vector2(-18, 0), 8.0, Color(1.0, 0.76, 0.28, 0.16))


func _keep_text_readable() -> void:
	var normalized_direction := direction.normalized()
	visual_label.rotation = PI if normalized_direction.x < 0.0 else 0.0
