local PlayerData = {}

local QBCore
local HasAlreadyEnteredMarker = false
local LastZone
local CurrentAction
local CurrentActionMsg = ''
local CurrentActionData = {}
local ownerInit = false
local myIdentifier
local pauseThread = 8

QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('buyable_carwash:saveOwners')
AddEventHandler('buyable_carwash:saveOwners', function(Owners, me)
    for k, v in pairs(Owners) do
        if (Config.Zones[v.name] ~= nil) then
            Config.Zones[v.name].Owner = v.owner
            Config.Zones[v.name].isForSale = v.isForSale
        end
    end
    myIdentifier = me
    ownerInit = true;
end)

RegisterNetEvent('buyable_carwash:carwashBought')
AddEventHandler('buyable_carwash:carwashBought', function(zone, owner)
    SetBlipColour(Config.Zones[zone].Washer.Blip, 2)
    Config.Zones[zone].Owner = owner
    Config.Zones[zone].isForSale = false
end)

RegisterNetEvent('buyable_carwash:cancelSelling')
AddEventHandler('buyable_carwash:cancelSelling', function(zone, owner)
    SetBlipColour(Config.Zones[zone].Washer.Blip, 2)
end)

RegisterNetEvent('buyable_carwash:carwashForSale')
AddEventHandler('buyable_carwash:carwashForSale', function(zone, price)
    SetBlipColour(Config.Zones[zone].Washer.Blip, 5)
    Config.Zones[zone].isForSale = true
end)

RegisterNetEvent('buyable_carwash:clean')
AddEventHandler('buyable_carwash:clean', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local dirtLevel = GetVehicleDirtLevel(vehicle)
    local displayPrice = math.floor(dirtLevel * Config.Price)
    local timer = Config.Timer * 1000
    FreezeEntityPosition(vehicle, true)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('cleaning_vehicle'))
    EndTextCommandThefeedPostTicker(true, true)
    Citizen.Wait(timer)
    WashDecalsFromVehicle(GetVehiclePedIsUsing(GetPlayerPed(-1)), 1.0)
    SetVehicleDirtLevel(vehicle, 0.0)
    FreezeEntityPosition(vehicle, false)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('cleaned_vehicle', {displayPrice}))
    EndTextCommandThefeedPostTicker(true, true)
end)

RegisterNetEvent('buyable_carwash:cancel')
AddEventHandler('buyable_carwash:cancel', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local dirtLevel = GetVehicleDirtLevel(vehicle)
    local displayPrice = math.floor(dirtLevel * Config.Price)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(Lang:t('not_enough_money', {displayPrice}))
    EndTextCommandThefeedPostTicker(true, true)
end)

RegisterNetEvent('buyable_carwash:menuIsAlreadyOpened')
AddEventHandler('buyable_carwash:menuIsAlreadyOpened', function(zone, isAlreadyOpened)
  Config.Zones[zone].menuIsAlreadyOpened = isAlreadyOpened
end)

local price

AddEventHandler('buyable_carwash:hasEnteredMarker', function(zone, zoneType)
  local playerPed = PlayerPedId()

  if zoneType == 'washer' and IsPedInAnyVehicle(playerPed, false) then
    local dirtLevel = GetVehicleDirtLevel(GetVehiclePedIsIn(PlayerPedId(), false))
    local pricePreFormat = math.floor(dirtLevel * Config.Price)
    price = pricePreFormat - 0.01
    if price >= 1.0 then
      CurrentAction = 'carwash'
      CurrentActionMsg = Lang:t('press_wash', {pricePreFormat})
    else
      CurrentAction = 'carwash'
      CurrentActionMsg = Lang:t('no_wash_needed')
    end
  elseif zoneType == 'manage' and not Config.Zones[zone].menuIsAlreadyOpened then
    CurrentAction = 'manage'
    CurrentActionMsg = Lang:t('press_manage')
  elseif zoneType == 'buy' and not Config.Zones[zone].menuIsAlreadyOpened then
    CurrentAction = 'buy'
    CurrentActionMsg = Lang:t('press_buy')
  elseif Config.Zones[zone].menuIsAlreadyOpened then
    CurrentAction = 'isAlreadyOpened'
    CurrentActionMsg = Lang:t('menu_isAlreadyOpened')    
  end
    TriggerServerEvent('buyable_carwash:getOwners')
    CurrentActionData = { zone = zone }
end)

AddEventHandler('buyable_carwash:hasExitedMarker', function(zone)
    TriggerServerEvent('buyable_carwash:closeMenu', zone)
    CurrentAction = nil
    if Config.ESX then
      ESX.UI.Menu.CloseAll()
    end
end)

function initBlips()
    while not ownerInit do
        Citizen.Wait(10)
    end
    for k, v in pairs(Config.Zones) do
      Config.Zones[k].Washer.Blip = AddBlipForCoord(v.Washer.Pos.x, v.Washer.Pos.y, v.Washer.Pos.z)
      SetBlipSprite(Config.Zones[k].Washer.Blip, 100)
      SetBlipDisplay(Config.Zones[k].Washer.Blip, 4)
      SetBlipScale(Config.Zones[k].Washer.Blip, Config.Blip.Scale)
      if v.isForSale or v.Owner == '' or v.Owner == nil then
        SetBlipColour(Config.Zones[k].Washer.Blip, 5)
      else
        SetBlipColour(Config.Zones[k].Washer.Blip, 2)
      end
      BeginTextCommandSetBlipName("STRING")
      AddTextComponentString(Lang:t('carwash_blip'))
      EndTextCommandSetBlipName(Config.Zones[k].Washer.Blip)
      SetBlipAsShortRange(Config.Zones[k].Washer.Blip, true)
    end
    Citizen.Wait(500)
    ownerInit = false
end

function checkDistanceFromMarker (zone)
  return GetDistanceBetweenCoords(GetEntityCoords(GetPlayerPed(-1)), zone.Pos.x, zone.Pos.y, zone.Pos.z, true) < zone.Size.x
end

function OpenBuyMenu(zone)
  local waiting = true
  local isForsale1
  local elements = {}
    QBCore.Functions.TriggerCallback('buyable_carwash:isforsale', function(isForsale, price)
      if isForsale then
          table.insert(elements, { label = Lang:t('buy_carwash', {price}), type = 'buy_shop' })
          table.insert(elements, { label = Lang:t('cancel'), type = 'cancel' })
      end
      isForsale1 = isForsale
      waiting = false
    end, zone)
    while waiting do
        Citizen.Wait(10)
    end
end

function OpenProprioMenu(zone)
  local waiting = true
  local isForsale1
  local elements = {}

    QBCore.Functions.TriggerCallback('buyable_carwash:isforsale', function(isForsale, price)
      isForsale1 = isForsale
      waiting = false
    end, zone)

    while waiting do
      Citizen.Wait(10)
    end

    if isForsale1 then
      table.insert(elements, { label = Lang:t('cancel_selling'), type = 'cancel_selling' })
    elseif not isForsale1 then
      waiting = true
      QBCore.Functions.TriggerCallback('buyable_carwash:getAccountMoney', function (accountMoney)
        table.insert(elements, { label = (Lang:t('stored_money') .. '<span style="color:green;">%s</span>'):format(accountMoney) })
        waiting = false
      end, zone)

      while waiting do
          Citizen.Wait(10)
      end

      table.insert(elements, { label = Lang:t('withdraw_money'), type = 'withdraw_money' })
      table.insert(elements, { label = Lang:t('put_forsale'), type = 'put_forsale' })
    end

    openMenu({
      {
          header = Lang:t('shop_proprio'),
          isMenuHeader = true, -- Set to true to make a nonclickable title
      },
      {
          header = "Sub Menu Button",
          txt = "This goes to a sub menu",
          params = {
              event = "qb-menu:client:testMenu2",
              args = {
                  number = 1,
              }
          }
      },
      {
          header = "Sub Menu Button",
          txt = "This goes to a sub menu",
          disabled = true,
          -- hidden = true, -- doesnt create this at all if set to true
          params = {
              event = "qb-menu:client:testMenu2",
              args = {
                  number = 1,
              }
          }
      },
    })
end

RegisterNetEvent('qb-menu:client:testButton', function(data)
  TriggerEvent('QBCore:Notify', data.message)
end)

-- Create Blips
Citizen.CreateThread(function()
    initBlips()
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
    while not ownerInit do
        Citizen.Wait(10)
    end
    while true do
        Citizen.Wait(10)
        local isInMarker = false
        local currentZone, zoneType

        for k, v in pairs(Config.Zones) do
          if checkDistanceFromMarker(v.Washer) then
            isInMarker = true
            currentZone = k
            LastZone = k
            zoneType = 'washer'
          end
          if checkDistanceFromMarker(v.Manage) then
            isInMarker = true
            currentZone = k
            LastZone = k
            if v.Owner == myIdentifier then
              zoneType = 'manage'
            elseif v.isForSale then
              zoneType = 'buy'
            end
          end
        end
        if isInMarker and not HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = true
            TriggerEvent('buyable_carwash:hasEnteredMarker', currentZone, zoneType)
        end
        if not isInMarker and HasAlreadyEnteredMarker then
            HasAlreadyEnteredMarker = false
            TriggerEvent('buyable_carwash:hasExitedMarker', LastZone)
        end
    end
end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
    local coords, letSleep = GetEntityCoords(PlayerPedId()), true

    for k,v in pairs(Config.Zones) do
	     if Config.Washer.MarkerType ~= -1 and #(coords - v.Washer.Pos) < Config.DrawDistance then
         DrawMarker(Config.Washer.MarkerType, v.Washer.Pos.x, v.Washer.Pos.y, v.Washer.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Washer.Size.x, v.Washer.Size.y, v.Washer.Size.z, Config.Washer.MarkerColor.r, Config.Washer.MarkerColor.g, Config.Washer.MarkerColor.b, 100, false, false, 2, false, nil, nil, false)
         letSleep = false
	     end
       if (v.isForSale or v.Owner == myIdentifier) and Config.Manage.MarkerType ~= -1 and #(coords - v.Manage.Pos) < Config.DrawDistance then
         DrawMarker(Config.Manage.MarkerType, v.Manage.Pos.x, v.Manage.Pos.y, v.Manage.Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Manage.Size.x, v.Manage.Size.y, v.Manage.Size.z, Config.Manage.MarkerColor.r, Config.Manage.MarkerColor.g, Config.Manage.MarkerColor.b, 100, false, false, 2, true, nil, nil, false)
         letSleep = false
       end
    end

    if letSleep then
	     Wait(500)
    end
	end
end)

-- Key Controls
Citizen.CreateThread(function()
  while not ownerInit do
      Citizen.Wait(10)
  end
  while true do
    Citizen.Wait(0)
    if CurrentAction ~= nil then
      SetTextComponentFormat('STRING')
      AddTextComponentString(CurrentActionMsg)
      DisplayHelpTextFromStringLabel(0, 0, 1, -1)
      if CurrentAction == 'carwash' then
        if IsControlJustReleased(0, 38) then
          CurrentAction = nil
          TriggerServerEvent('buyable_carwash:checkMoney', price, CurrentActionData.zone)
        end
      elseif CurrentAction == 'manage' then
        if Config.Zones[CurrentActionData.zone].Owner == myIdentifier then
          if IsControlJustReleased(0, 38) then
            TriggerServerEvent('buyable_carwash:openMenu', CurrentActionData.zone)
            OpenProprioMenu(CurrentActionData.zone)
          end
        end
      elseif CurrentAction == 'buy' then
        if IsControlJustReleased(0, 38) then
          CurrentAction = nil
          TriggerServerEvent('buyable_carwash:openMenu', CurrentActionData.zone)
          OpenBuyMenu(CurrentActionData.zone)
        end
      end
    else
      Citizen.Wait(500)
    end
  end
end)
