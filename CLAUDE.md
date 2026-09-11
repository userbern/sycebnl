### Modification du sous-menu « Balance »

Dans le sous-menu **Balance**, modifier le comportement des options **Analytique** et **Analytique et tiers**.

Lorsqu’un utilisateur sélectionne l’une de ces deux options, le système doit d’abord lui demander de choisir le type de ventilation à consulter :

* **Fonctionnement**
* **Projet**
* **Fonctionnement + Projet**

#### 1. Fonctionnement

Si l’utilisateur sélectionne **Fonctionnement**, afficher tous les comptes ayant au moins une ventilation de type **Fonctionnement**.

#### 2. Projet

Si l’utilisateur sélectionne **Projet**, demander à l’utilisateur de sélectionner le ou les **bailleurs** concernés.

Après la sélection du ou des bailleurs, demander à l’utilisateur de choisir le type de projet :

* **Activité**
* **Administration**
* **Activité + Administration**

Le système affiche ensuite les comptes correspondant aux critères sélectionnés.

#### 3. Fonctionnement + Projet

Si l’utilisateur sélectionne **Fonctionnement + Projet**, appliquer les deux filtres :

* les comptes ayant une ventilation **Fonctionnement** ;
* les comptes liés à un **Projet**, avec sélection du ou des **bailleurs**.

Après la sélection des bailleurs, demander également le type de projet :

* **Activité**
* **Administration**
* **Activité + Administration**

### Parcours attendu

**Analytique / Analytique et tiers**
→ Choix : **Fonctionnement / Projet / Fonctionnement + Projet**

**Si Fonctionnement**
→ Afficher les comptes avec ventilation Fonctionnement.

**Si Projet**
→ Choisir le(s) bailleur(s)
→ Choisir : **Activité / Administration / Activité + Administration**
→ Afficher les comptes correspondants.

**Si Fonctionnement + Projet**
→ Choisir le(s) bailleur(s)
→ Choisir : **Activité / Administration / Activité + Administration**
→ Afficher les comptes correspondant aux deux types de ventilation.
