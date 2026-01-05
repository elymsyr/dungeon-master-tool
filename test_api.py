import requests
import json
import time

# API Temel URL'i
BASE_URL = "https://www.dnd5eapi.co"

# Senin verdiğin kategori listesi
categories_json = """
{"count":39,"results":[{"index":"adventuring-gear","name":"Adventuring Gear","url":"/api/2014/equipment-categories/adventuring-gear"},{"index":"ammunition","name":"Ammunition","url":"/api/2014/equipment-categories/ammunition"},{"index":"arcane-foci","name":"Arcane Foci","url":"/api/2014/equipment-categories/arcane-foci"},{"index":"armor","name":"Armor","url":"/api/2014/equipment-categories/armor"},{"index":"artisans-tools","name":"Artisan's Tools","url":"/api/2014/equipment-categories/artisans-tools"},{"index":"druidic-foci","name":"Druidic Foci","url":"/api/2014/equipment-categories/druidic-foci"},{"index":"equipment-packs","name":"Equipment Packs","url":"/api/2014/equipment-categories/equipment-packs"},{"index":"gaming-sets","name":"Gaming Sets","url":"/api/2014/equipment-categories/gaming-sets"},{"index":"heavy-armor","name":"Heavy Armor","url":"/api/2014/equipment-categories/heavy-armor"},{"index":"holy-symbols","name":"Holy Symbols","url":"/api/2014/equipment-categories/holy-symbols"},{"index":"kits","name":"Kits","url":"/api/2014/equipment-categories/kits"},{"index":"land-vehicles","name":"Land Vehicles","url":"/api/2014/equipment-categories/land-vehicles"},{"index":"light-armor","name":"Light Armor","url":"/api/2014/equipment-categories/light-armor"},{"index":"martial-melee-weapons","name":"Martial Melee Weapons","url":"/api/2014/equipment-categories/martial-melee-weapons"},{"index":"martial-ranged-weapons","name":"Martial Ranged Weapons","url":"/api/2014/equipment-categories/martial-ranged-weapons"},{"index":"martial-weapons","name":"Martial Weapons","url":"/api/2014/equipment-categories/martial-weapons"},{"index":"medium-armor","name":"Medium Armor","url":"/api/2014/equipment-categories/medium-armor"},{"index":"melee-weapons","name":"Melee Weapons","url":"/api/2014/equipment-categories/melee-weapons"},{"index":"mounts-and-other-animals","name":"Mounts and Other Animals","url":"/api/2014/equipment-categories/mounts-and-other-animals"},{"index":"mounts-and-vehicles","name":"Mounts and Vehicles","url":"/api/2014/equipment-categories/mounts-and-vehicles"},{"index":"musical-instruments","name":"Musical Instruments","url":"/api/2014/equipment-categories/musical-instruments"},{"index":"other-tools","name":"Other Tools","url":"/api/2014/equipment-categories/other-tools"},{"index":"potion","name":"Potion","url":"/api/2014/equipment-categories/potion"},{"index":"ranged-weapons","name":"Ranged Weapons","url":"/api/2014/equipment-categories/ranged-weapons"},{"index":"ring","name":"Ring","url":"/api/2014/equipment-categories/ring"},{"index":"rod","name":"Rod","url":"/api/2014/equipment-categories/rod"},{"index":"scroll","name":"Scroll","url":"/api/2014/equipment-categories/scroll"},{"index":"shields","name":"Shields","url":"/api/2014/equipment-categories/shields"},{"index":"simple-melee-weapons","name":"Simple Melee Weapons","url":"/api/2014/equipment-categories/simple-melee-weapons"},{"index":"simple-ranged-weapons","name":"Simple Ranged Weapons","url":"/api/2014/equipment-categories/simple-ranged-weapons"},{"index":"simple-weapons","name":"Simple Weapons","url":"/api/2014/equipment-categories/simple-weapons"},{"index":"staff","name":"Staff","url":"/api/2014/equipment-categories/staff"},{"index":"standard-gear","name":"Standard Gear","url":"/api/2014/equipment-categories/standard-gear"},{"index":"tack-harness-and-drawn-vehicles","name":"Tack, Harness, and Drawn Vehicles","url":"/api/2014/equipment-categories/tack-harness-and-drawn-vehicles"},{"index":"tools","name":"Tools","url":"/api/2014/equipment-categories/tools"},{"index":"wand","name":"Wand","url":"/api/2014/equipment-categories/wand"},{"index":"waterborne-vehicles","name":"Waterborne Vehicles","url":"/api/2014/equipment-categories/waterborne-vehicles"},{"index":"weapon","name":"Weapon","url":"/api/2014/equipment-categories/weapon"},{"index":"wondrous-items","name":"Wondrous Items","url":"/api/2014/equipment-categories/wondrous-items"}]}
"""

def get_example_from_categories():
    data = json.loads(categories_json)
    categories = data['results']
    
    output_filename = "api_ornekleri.txt"
    
    with open(output_filename, "w", encoding="utf-8") as f:
        f.write("Aşağıda D&D 5e API'sinden çekilmiş, her kategoriden birer örnek item verisi bulunmaktadır.\n")
        f.write("Lütfen bu verileri analiz ederek tüm varyasyonları kapsayan bir veri yapısı (entity) oluştur.\n\n")
        
        print(f"Toplam {len(categories)} kategori taranacak...")
        
        for index, cat in enumerate(categories):
            cat_name = cat['name']
            cat_url = cat['url']
            cat_index = cat['index']
            
            print(f"[{index+1}/{len(categories)}] İşleniyor: {cat_name}...")
            
            try:
                # 1. Kategorinin içine girip item listesini al
                response_cat = requests.get(BASE_URL + cat_url)
                response_cat.raise_for_status()
                cat_data = response_cat.json()
                
                # 'equipment' listesini kontrol et
                item_list = cat_data.get('equipment', [])
                
                if not item_list:
                    # Bazı durumlarda magic itemlar farklı key altında olabilir veya liste boş olabilir
                    f.write(f"--- KATEGORİ: {cat_name} ({cat_index}) ---\n")
                    f.write("Bu kategoride doğrudan 'equipment' listesi bulunamadı veya boş.\n")
                    f.write("--------------------------------------------------\n\n")
                    continue

                # 2. Listeden ilk itemi seç
                first_item = item_list[0]
                item_url = first_item['url']
                
                # 3. O itemin detayına git
                response_item = requests.get(BASE_URL + item_url)
                response_item.raise_for_status()
                item_detail = response_item.json()
                
                # 4. Dosyaya yaz
                f.write(f"--- KATEGORİ: {cat_name} ({cat_index}) ---\n")
                f.write(f"Örnek Item: {item_detail.get('name', 'Unknown')}\n")
                f.write(json.dumps(item_detail, indent=2, ensure_ascii=False))
                f.write("\n--------------------------------------------------\n\n")
                
            except Exception as e:
                print(f"Hata oluştu ({cat_name}): {e}")
                f.write(f"--- KATEGORİ: {cat_name} ---\n")
                f.write(f"HATA: Veri çekilirken hata oluştu: {str(e)}\n")
                f.write("--------------------------------------------------\n\n")
            
            # API'yi yormamak için kısa bir bekleme
            time.sleep(0.5)

    print(f"\nİşlem tamamlandı! '{output_filename}' dosyası oluşturuldu.")

if __name__ == "__main__":
    get_example_from_categories()