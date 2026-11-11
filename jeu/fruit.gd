# Fabrique l'apparence d'un pilote : un fruit assis dans son kart.
# Tout est tourné vers l'avant du kart, c'est-à-dire vers -Z.
extends RefCounted


static func creer(pilote: Dictionary) -> Node3D:
	var chemin: String = pilote.get("modele", "")
	if chemin != "":
		if ResourceLoader.exists(chemin):
			var modele: Node3D = load(chemin).instantiate()
			modele.scale = Vector3.ONE * float(pilote.get("modele_taille", 1.0))
			modele.rotation_degrees.y = float(pilote.get("modele_rotation", 0))
			return modele
		push_warning("Modèle introuvable pour %s : %s. On garde les formes simples." % [pilote["nom"], chemin])

	var kart := Node3D.new()
	var carrosserie := _matiere(pilote["kart"])
	_ajouter(kart, _boite(Vector3(1.3, 0.35, 2.3)), carrosserie, Vector3(0, 0.45, 0))
	_ajouter(kart, _boite(Vector3(0.8, 0.25, 0.7)), carrosserie, Vector3(0, 0.4, -1.4))
	_ajouter(kart, _boite(Vector3(1.5, 0.12, 0.3)), carrosserie, Vector3(0, 0.85, 1.1))  # l'aileron

	var roue := CylinderMesh.new()
	roue.top_radius = 0.34
	roue.bottom_radius = 0.34
	roue.height = 0.3
	var pneu := _matiere("#222222")
	for x in [-0.8, 0.8]:
		for z in [-0.85, 0.8]:
			_ajouter(kart, roue, pneu, Vector3(x, 0.34, z)).rotation_degrees.z = 90

	kart.add_child(_fruit(pilote))
	return kart


static func _fruit(pilote: Dictionary) -> Node3D:
	var fruit := Node3D.new()
	var peau := _matiere(pilote["couleur"])
	match pilote.get("forme", "ronde"):
		"longue":
			var corps := CapsuleMesh.new()
			corps.radius = 0.35
			corps.height = 1.6
			_ajouter(fruit, corps, peau, Vector3.ZERO).rotation_degrees.x = 20
		"pointue":
			var corps := CylinderMesh.new()
			corps.top_radius = 0.65
			corps.bottom_radius = 0.05
			corps.height = 1.3
			_ajouter(fruit, corps, peau, Vector3.ZERO)
		_:
			_ajouter(fruit, _boule(0.65), peau, Vector3.ZERO)

	_ajouter(fruit, _boite(Vector3(0.08, 0.3, 0.08)), _matiere("#6d4c2f"), Vector3(0, 0.75, 0))
	_ajouter(fruit, _boule(0.2), _matiere("#43a047"), Vector3(0.2, 0.8, 0)).scale = Vector3(1.4, 0.3, 0.8)
	for x in [-0.22, 0.22]:
		_ajouter(fruit, _boule(0.15), _matiere("#ffffff"), Vector3(x, 0.2, -0.5))
		_ajouter(fruit, _boule(0.07), _matiere("#111111"), Vector3(x, 0.2, -0.63))

	var taille: float = pilote.get("taille", 1.0)
	fruit.scale = Vector3.ONE * taille
	fruit.position = Vector3(0, 0.6 + 0.65 * taille, 0.2)
	return fruit


static func _ajouter(parent: Node3D, forme: Mesh, matiere: Material, ou: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = forme
	m.material_override = matiere
	m.position = ou
	parent.add_child(m)
	return m


static func _boite(taille: Vector3) -> BoxMesh:
	var boite := BoxMesh.new()
	boite.size = taille
	return boite


static func _boule(rayon: float) -> SphereMesh:
	var boule := SphereMesh.new()
	boule.radius = rayon
	boule.height = rayon * 2.0
	boule.radial_segments = 20
	boule.rings = 10
	return boule


static func _matiere(couleur: String) -> StandardMaterial3D:
	var matiere := StandardMaterial3D.new()
	matiere.albedo_color = Color(couleur)
	return matiere
