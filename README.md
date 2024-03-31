<div id="header" align="center">
  <img src="https://media.discordapp.net/attachments/1036244419881476106/1224139111556976771/MBT_MALISLING.png?ex=661c6763&is=6609f263&hm=58b81230d2307fd40c8cf48e7b1ef77a957c6f010a1007b67a078824d8dfe219" width="500"/>
</div>

Take your weapon experience to the next level! With cool features like visible weapons, realistic jamming chance based on weapon durability, dropping equipped weapons on death, throwing weapons   and holster animation, you get a more engaging and immersive gameplay experience. Check it out now!

### Dependencies:
* [ox_inventory](https://github.com/overextended/ox_inventory)
* [ox_lib](https://github.com/overextended/ox_lib)

### ⚠️Important:
The resource has been tested ONLY on Ox Core and ESX and ONLY with a restricted amount of players\
In order to allow the holster feature to work, the functions
```Weapon.Disarm``` and ```Weapon.Equip``` have been slightly edited and appended after the existing ones\
Don't know if it was the best option, but its the one popped up in my head\
This also means that any update of ```ox_inventory``` that invoves them, can break the script behavior

## Features

* ESX/OX/QB compatible
* Very low CPU usage
* Weapon attached to player based on type
* Holster animation
* Synced attachments
* Flashlight state synced
* Flashlight working on back
* Jamming chance based on weapon state
* Equipped weapon drops on death
* Export for dropping equipped weapon from hands
* Throw weapons away ad turn them into drops
* Easily config script with your own event to fit your needs
* Customizable weapon position
* Customizable weapon position for jobs and gender
* Customizable animations
* Customizable jamming chance
* Customizable throwing power (based on weapon groups)
* Customizable labels
* Customizable notifications (Preset with ox_lib)
* Customizable UI Help (Preset with ox_lib)
* Customizable skillbar event(Preset with ox_lib)

## Usage

Put the script in your resource directory\
Ensure it after ox_inventory\
After the first start, restart the server (so the convar of sling can work properly)\
Open the ```config.lua``` and read it carefully\
Set the weapons type to suit your tastes (or add other ones) in the ```data/weapons.lua```  

# Common Issues

### Some attachments are not applying properly to attached weapon

It seems its some kind of limitation of GTAV (as far as i know)
If someone has some info about it, we will be very happy of receive a PR	

## Media:
- Showcase:  [Click Here](https://www.youtube.com/watch?v=A5NDT_WTbo0)
- Cfx : [Click Here](https://forum.cfx.re/t/free-esx-ox-qb-mbt-malisling-attached-weapons-flashlights-jamming-weapon-drop-throw/5118366)

## DMCA Protection Certificate
![image](https://media.discordapp.net/attachments/1045063739738705940/1119276600584847370/dmca.png?ex=66194910&is=6606d410&hm=682e73fe82b3ae29ac3753c8a61d5c3d7c6b7307e926ac9a0effef0646a73b0c&=&format=webp&quality=lossless&width=1136&height=905)

##### Copyright © 2023 Malibú Tech. All rights reserved.
