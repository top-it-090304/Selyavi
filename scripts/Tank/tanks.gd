extends Node
class_name Tanks

var hp: float
var speed: int

func move() -> float:
	push_error("Метод move() должен быть переопределен")
	return 0.0

func fire():
	push_error("Метод fire() должен быть переопределен")

func destroy_tank():
	push_error("Метод destroy_tank() должен быть переопределен")
