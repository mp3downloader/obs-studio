//
//  obs-basic-recordingconfig.cpp
//  obs
//
//  Created by tony on 2019/7/28.
//

#include <stdio.h>
#include <QComboBox>
#include <QStandardItem>
#include <QDebug>

#include "window-basic-main.hpp"
#include "qt-wrappers.hpp"

using namespace std;


#define DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE "display_capture-0"
#define DEFAULT_SOURCE_NAME_WINDOW_CAPTURE "window_capture-0"
#define DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT "av_capture_input-0"
#define DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE "coreaudio_input_capture-0"
#define DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE "coreaudio_output_capture-0"

#define ICON_DISPLAY_ON QIcon(":/recorder/images/recorder/display.svg")
#define ICON_DISPLAY_OFF QIcon(":/recorder/images/recorder/display-off.svg")
#define ICON_WINDOW_ON QIcon(":/recorder/images/recorder/window.svg")
#define ICON_WINDOW_OFF QIcon(":/recorder/images/recorder/window-off.svg")
#define ICON_CAMERA_ON QIcon(":/recorder/images/recorder/camera.svg")
#define ICON_CAMERA_OFF QIcon(":/recorder/images/recorder/camera-off.svg")
#define ICON_MIC_ON QIcon(":/recorder/images/recorder/micphone.svg")
#define ICON_MIC_OFF QIcon(":/recorder/images/recorder/micphone-off.svg")
#define ICON_AUDIO_ON QIcon(":/recorder/images/recorder/audio.svg")
#define ICON_AUDIO_OFF QIcon(":/recorder/images/recorder/audio-off.svg")


#define DEFAULT_SOURCES_COUNT 5
static const char *default_sources[DEFAULT_SOURCES_COUNT] = {"display_capture", "window_capture", "av_capture_input", "coreaudio_input_capture", "coreaudio_output_capture"};
static const char *default_sources_name[DEFAULT_SOURCES_COUNT] = {DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE, DEFAULT_SOURCE_NAME_WINDOW_CAPTURE, DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT, DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE, DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE};

struct AddSourceData {
    obs_source_t *source;
    bool visible;
};

static bool enumItem(obs_scene_t *, obs_sceneitem_t *item, void *ptr)
{
    QVector<OBSSceneItem> &items =
    *reinterpret_cast<QVector<OBSSceneItem> *>(ptr);
    
    if (obs_sceneitem_is_group(item)) {
        obs_data_t *data = obs_sceneitem_get_private_settings(item);
        
        bool collapse = obs_data_get_bool(data, "collapsed");
        if (!collapse) {
            obs_scene_t *scene =
            obs_sceneitem_group_get_scene(item);
            
            obs_scene_enum_items(scene, enumItem, &items);
        }
        
        obs_data_release(data);
    }
    
    items.insert(0, item);
    return true;
}


static bool ContainsSource(OBSScene scene, const char *sourceID)
{
    QVector<OBSSceneItem> sceneItems;
    obs_scene_enum_items(scene, enumItem, &sceneItems);

    for (int i = 0; i < sceneItems.count(); i++)
    {
        OBSSource source = obs_sceneitem_get_source(sceneItems.at(i));
    
        if (strcmp(sourceID, obs_source_get_id(source)) == 0)
            return true;
    }
    
    return false;
}

static void AddSourceFunc(void *_data, obs_scene_t *scene)
{
    AddSourceData *data = (AddSourceData *)_data;
    obs_sceneitem_t *sceneitem;
    
    sceneitem = obs_scene_add(scene, data->source);
    obs_sceneitem_set_visible(sceneitem, data->visible);
}


static bool AddDefaultSource(OBSScene scene, const char *id, const char *name)
{
    bool success = false;
    if (!scene)
        return success;
    
    
    OBSSource source = obs_source_create(id, name, NULL, nullptr);
    
    if (source)
    {
        AddSourceData data;
        data.source = source;
        data.visible = false;
        
        obs_enter_graphics();
        obs_scene_atomic_update(scene, AddSourceFunc, &data);
        obs_leave_graphics();
        
        success = true;
    }
    
    obs_source_release(source);
    return success;
}

template<long long get_int(obs_data_t *, const char *),
     double get_double(obs_data_t *, const char *),
     const char *get_string(obs_data_t *, const char *)>
static string from_obs_data(obs_data_t *data, const char *name,
                obs_combo_format format)
{
    switch (format) {
    case OBS_COMBO_FORMAT_INT:
        return to_string(get_int(data, name));
    case OBS_COMBO_FORMAT_FLOAT:
        return to_string(get_double(data, name));
    case OBS_COMBO_FORMAT_STRING:
        return get_string(data, name);
    default:
        return "";
    }
}

static string from_obs_data(obs_data_t *data, const char *name,
                obs_combo_format format)
{
    return from_obs_data<obs_data_get_int, obs_data_get_double,
                 obs_data_get_string>(data, name, format);
}

static string from_obs_data_autoselect(obs_data_t *data, const char *name,
                       obs_combo_format format)
{
    return from_obs_data<obs_data_get_autoselect_int,
                 obs_data_get_autoselect_double,
                 obs_data_get_autoselect_string>(data, name,
                                 format);
}


static void AddComboItem(QComboBox *combo, obs_property_t *prop,
                         obs_combo_format format, size_t idx)
{
    if (obs_property_list_item_disabled(prop, idx))
        return;
    
    const char *name = obs_property_list_item_name(prop, idx);

//    if (name == NULL || strlen(name) == 0)
//        return;
    
    QVariant var;
    
    if (format == OBS_COMBO_FORMAT_INT) {
        long long val = obs_property_list_item_int(prop, idx);
        var = QVariant::fromValue<long long>(val);
        
    } else if (format == OBS_COMBO_FORMAT_FLOAT) {
        double val = obs_property_list_item_float(prop, idx);
        var = QVariant::fromValue<double>(val);
        
    } else if (format == OBS_COMBO_FORMAT_STRING) {
        var = QByteArray(obs_property_list_item_string(prop, idx));
    }
    
    combo->addItem(QT_UTF8(name), var);
    
//    if (!obs_property_list_item_disabled(prop, idx))
//        return;
//
//    int index = combo->findText(QT_UTF8(name));
//    if (index < 0)
//        return;
//
//    QStandardItemModel *model =
//    dynamic_cast<QStandardItemModel *>(combo->model());
//    if (!model)
//        return;
//
//    QStandardItem *item = model->item(index);
//    item->setFlags(Qt::NoItemFlags);
}

static void populateDevice(QComboBox *comboBox, obs_property_t *property, OBSData settings)
{
    const char *propertyName = obs_property_name(property);
    int count = obs_property_list_item_count(property);
    
    obs_combo_format format = obs_property_list_format(property);
    
    comboBox->blockSignals(true);
    comboBox->clear();
    
    for (size_t i = 0; i < count; i++)
        AddComboItem(comboBox, property, format, i);
    
    //设置选中项
    int idx = -1;
    std::string value = from_obs_data(settings, propertyName, format);
    
    idx = comboBox->findData(QByteArray(value.c_str()));
    
    //if (idx != -1)
    comboBox->setCurrentIndex(idx);
    

    comboBox->blockSignals(false);
}

static obs_property_t *getListProperty(const char* sourceName, const char *propertyName)
{
    OBSSource source = obs_get_source_by_name(sourceName);
    if (source)
    {
        obs_properties_t *properties = obs_source_properties(source);
        obs_property_t *property = obs_properties_get(properties, propertyName);
        return property;
    }
    else
    {
        qDebug() << "Can't get source " << sourceName;
        return nullptr;
    }
}

static OBSData getSourceSettings(const char *sourceName)
{
    OBSSource source = obs_get_source_by_name(sourceName);
    if (source)
    {
        OBSData settings = obs_source_get_settings(source);
        return settings;
    }
    else
    {
        qDebug() << "Can't get source " << sourceName;
        return nullptr;
    }
}


static void toggleSourceVisible(OBSSceneItem si)
{
    Q_ASSERT(si != nullptr);
    
    if (obs_sceneitem_visible(si))
        obs_sceneitem_set_visible(si, false);
    else
        obs_sceneitem_set_visible(si, true);
}

static void updateButtonIcon(QPushButton *button, OBSSceneItem si, QIcon icon, QIcon iconAlternative)
{
    Q_ASSERT(si);
    
    if (obs_sceneitem_visible(si))
    {
        button->setIcon(icon);
    }
    else
    {
        button->setIcon(iconAlternative);
    }
}


int OBSBasic::AddDefaultSourcesForRecording()
{
    OBSScene scene = GetCurrentScene();
    OBSSource curProgramScene = OBSGetStrongRef(programScene);
    if (!curProgramScene)
        curProgramScene = obs_scene_get_source(scene);
    
    //判断scene是否包含特定source 屏幕、window、camara、microphone、systemaudio
    for (int i = 0; i < DEFAULT_SOURCES_COUNT; i++)
        if (!ContainsSource(scene, default_sources[i]))
        {
            AddDefaultSource(scene, default_sources[i], default_sources_name[i]);
        }
    
    return 0;
}


//初始化界面。设备列表。按钮是否显示。音频音量（后续）。
void OBSBasic::InitRecordingUI()
{
    //displaycapture
    obs_property_t *displayListProperty = getListProperty(DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE, "display");
    OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE);
    populateDevice(ui->comboBoxDisplayList, displayListProperty, sourceSettings);
    
    //windowcapture
    obs_property_t *windowListProperty = getListProperty(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE, "window");
    sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE);
    populateDevice(ui->comboBoxWindowList, windowListProperty, sourceSettings);
    
    
    //camera
    obs_property_t *videoDeviceListProperty = getListProperty(DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT, "device");
    sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT);
    populateDevice(ui->comboBoxVideoDeviceList, videoDeviceListProperty, sourceSettings);
    
    if (ui->comboBoxVideoDeviceList->count() > 0 && ui->comboBoxVideoDeviceList->currentIndex() == -1)
        ui->comboBoxVideoDeviceList->setCurrentIndex(0);

    
    //inputaudio
    obs_property_t *inputAudioListProperty = getListProperty(DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE, "device_id");
    sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE);
    populateDevice(ui->comboBoxInputAudioList, inputAudioListProperty, sourceSettings);

    
    //output audio
    obs_property_t *outputAudioListProperty = getListProperty(DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE, "device_id");
    sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE);
    populateDevice(ui->comboBoxOutputAudioList, outputAudioListProperty, sourceSettings);
    
    
    
    //update button icon
    OBSSceneItem si =  obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE);
    if (si)
    {
        updateButtonIcon(ui->recordDisplayButton, si, ICON_DISPLAY_ON, ICON_DISPLAY_OFF);
    }
    si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_WINDOW_CAPTURE);
    if (si)
    {
        updateButtonIcon(ui->recordWindowButton, si, ICON_WINDOW_ON, ICON_WINDOW_OFF);
    }
    si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT);
    if (si)
    {
        updateButtonIcon(ui->recordCameraButton, si, ICON_CAMERA_ON, ICON_CAMERA_OFF);
    }
    si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE);
    if (si)
    {
        updateButtonIcon(ui->recordMicphoneButton, si, ICON_MIC_ON, ICON_MIC_OFF);
    }
    si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE);
    if (si)
    {
        updateButtonIcon(ui->recordSystemAudioButton, si, ICON_AUDIO_ON, ICON_AUDIO_OFF);
    }
    
}



void OBSBasic::on_recordDisplayButton_clicked()
{
    OBSSceneItem si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE);
    if (si)
    {
        toggleSourceVisible(si);
        
        //获取新的设备列表
//        if (obs_sceneitem_visible(si))
//        {
//            obs_property_t *displayListProperty = getListProperty(DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE, "display");
//            OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE);
//            populateDevice(ui->comboBoxDisplayList, displayListProperty, sourceSettings);
//        }
        
        updateButtonIcon(ui->recordDisplayButton, si, ICON_DISPLAY_ON, ICON_DISPLAY_OFF);
    }
}

void OBSBasic::on_recordWindowButton_clicked()
{
    OBSSceneItem si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_WINDOW_CAPTURE);
    if (si)
    {
        OBSSource source = obs_sceneitem_get_source(si);
        OBSData settings = obs_source_get_settings(source);
        int windowId = obs_data_get_int(settings, "window");
        if (windowId == 0)
            printf("Please select a window\n");
        
        obs_properties_t *properties = obs_source_properties(source);
        obs_property_t *property =  obs_properties_get(properties, "window");
        int itemCount = obs_property_list_item_count(property);
        for (int i = 0; i < itemCount; i++)
        {
            const char *itemName = obs_property_list_item_name(property, i);
            printf("itemName %s\n",itemName);
        }
        
        //提示选择窗口
        
        //弹出菜单
        
        toggleSourceVisible(si);
        
        //获取新的设备列表
        if (obs_sceneitem_visible(si))
        {
//            obs_property_t *windowListProperty = getListProperty(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE, "window");
//            OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE);
//            populateDevice(ui->comboBoxWindowList, windowListProperty, sourceSettings);
        }
        
        updateButtonIcon(ui->recordWindowButton, si, ICON_WINDOW_ON, ICON_WINDOW_OFF);
    }
}

void OBSBasic::on_recordCameraButton_clicked()
{
    OBSSceneItem si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT);
    if (si)
    {
        toggleSourceVisible(si);
    
    //检测是否有设备
    
    //检测是否选择了设备
    
    //提示选择一个设备
        
        //获取新的设备列表
//        if (obs_sceneitem_visible(si))
//        {
//            obs_property_t *videoDeviceListProperty = getListProperty(DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT, "device");
//            OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT);
//            populateDevice(ui->comboBoxVideoDeviceList, videoDeviceListProperty, sourceSettings);
//        }
        
        updateButtonIcon(ui->recordCameraButton, si, ICON_CAMERA_ON, ICON_CAMERA_OFF);
    }
}

void OBSBasic::on_recordMicphoneButton_clicked()
{
    OBSSceneItem si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE);
    if (si)
    {
        toggleSourceVisible(si);
    
    //检测是否有设备
    
    //检测是否选择了设备
    
    //提示选择一个设备
        
        //获取新的设备列表
//        if (obs_sceneitem_visible(si))
//        {
//            obs_property_t *inputAudioListProperty = getListProperty(DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE, "device_id");
//            OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE);
//            populateDevice(ui->comboBoxInputAudioList, inputAudioListProperty, sourceSettings);
//        }
        
        updateButtonIcon(ui->recordMicphoneButton, si, ICON_MIC_ON, ICON_MIC_OFF);
    }
}

void OBSBasic::on_recordSystemAudioButton_clicked()
{
    OBSSceneItem si = obs_scene_find_source(GetCurrentScene(), DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE);
    if (si)
    {
        toggleSourceVisible(si);
    
    //检测是否有设备
    
    //检测是否选择了设备
    
    //提示选择一个设备
    
        //获取新的设备列表
//        if (obs_sceneitem_visible(si))
//        {
//            obs_property_t *outputAudioListProperty = getListProperty(DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE, "device_id");
//            OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE);
//            populateDevice(ui->comboBoxOutputAudioList, outputAudioListProperty, sourceSettings);
//        }
        
        updateButtonIcon(ui->recordSystemAudioButton, si, ICON_AUDIO_ON, ICON_AUDIO_OFF);
    }
    
}



static void listChanged(QComboBox *comboBox, const char *sourceName, const char *propertyName)
{
    obs_source_t *source = obs_get_source_by_name(sourceName);
    obs_properties_t *properties = obs_source_properties(source);
    obs_property_t *property =  obs_properties_get(properties, propertyName);
    obs_data_t *settings = obs_source_get_settings(source);
    
    obs_combo_format format = obs_property_list_format(property);

    
    QVariant data;
    
    int index = comboBox->currentIndex();
    if (index != -1)
        data = comboBox->itemData(index);
    else
        return;
    
    switch (format) {
        case OBS_COMBO_FORMAT_INVALID:
            return;
        case OBS_COMBO_FORMAT_INT:
            obs_data_set_int(settings, propertyName,
                             data.value<long long>());
            break;
        case OBS_COMBO_FORMAT_FLOAT:
            obs_data_set_double(settings, propertyName,
                                data.value<double>());
            break;
        case OBS_COMBO_FORMAT_STRING:
            obs_data_set_string(settings, propertyName,
                                data.toByteArray().constData());
            break;
    }
    
    obs_source_update(source, settings);
}

//displaycapture
void OBSBasic::on_comboBoxDisplayList_currentIndexChanged(int idx)
{
    listChanged(ui->comboBoxDisplayList, DEFAULT_SOURCE_NAME_DISPLAY_CAPTURE, "display");
}


//windowcapture
void OBSBasic::on_comboBoxWindowList_currentIndexChanged(int idx)
{
    listChanged(ui->comboBoxWindowList, DEFAULT_SOURCE_NAME_WINDOW_CAPTURE, "window");
}
void OBSBasic::on_comboBoxWindowList_clicked()
{
    obs_property_t *windowListProperty = getListProperty(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE, "window");
    OBSData sourceSettings = getSourceSettings(DEFAULT_SOURCE_NAME_WINDOW_CAPTURE);
    populateDevice(ui->comboBoxWindowList, windowListProperty, sourceSettings);
}

//camera
void OBSBasic::on_comboBoxVideoDeviceList_currentIndexChanged(int idx)
{
    listChanged(ui->comboBoxVideoDeviceList, DEFAULT_SOURCE_NAME_AV_CAPTURE_INPUT, "device");
}

//inputaudio
void OBSBasic::on_comboBoxInputAudioList_currentIndexChanged(int idx)
{
    listChanged(ui->comboBoxInputAudioList, DEFAULT_SOURCE_NAME_COREAUDIO_INPUT_CAPTURE, "device_id");
}

//output audio
void OBSBasic::on_comboBoxOutputAudioList_currentIndexChanged(int idx)
{
    listChanged(ui->comboBoxOutputAudioList, DEFAULT_SOURCE_NAME_COREAUDIO_OUTPUT_CAPTURE, "device_id");
}

