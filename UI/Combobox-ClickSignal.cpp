//
//  Combobox-ClickSignal.cpp
//  obs
//
//  Created by mac on 2020/5/5.
//

#include "Combobox-ClickSignal.hpp"

ComboBoxClickSignal::ComboBoxClickSignal(QWidget *parent) : QComboBox(parent)
{
    
}

void ComboBoxClickSignal::mousePressEvent(QMouseEvent *event)
{
    if(event->button() == Qt::LeftButton)
    {
        emit clicked();  //触发clicked信号
    }
    
    QComboBox::mousePressEvent(event);
}
