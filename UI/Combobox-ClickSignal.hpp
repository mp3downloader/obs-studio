//
//  Combobox-ClickSignal.hpp
//  obs
//
//  Created by mac on 2020/5/5.
//

#ifndef Combobox_ClickSignal_hpp
#define Combobox_ClickSignal_hpp

#include <QComboBox>
#include <QMouseEvent>

class ComboBoxClickSignal : public QComboBox {
    
    Q_OBJECT

public:
    ComboBoxClickSignal(QWidget *parent = nullptr);

protected:
    virtual void mousePressEvent(QMouseEvent *event) override;
    
signals:
    void clicked();
};

#endif /* Combobox_ClickSignal_hpp */
