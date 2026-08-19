import SwiftUI
import UIKit


struct ReliableDecimalTextField:
    UIViewRepresentable {

    @Binding
    var text:
        String

    var placeholder:
        String = "0.00"

    var font:
        UIFont =
            .systemFont(
                ofSize: 17
            )

    var alignment:
        NSTextAlignment =
            .natural


    func makeCoordinator()
        -> Coordinator {

        Coordinator(
            text:
                $text
        )
    }


    func makeUIView(
        context:
            Context
    ) -> UITextField {

        let textField =
            UITextField()

        textField.placeholder =
            placeholder

        textField.keyboardType =
            .decimalPad

        textField.font =
            font

        textField.textAlignment =
            alignment

        textField.textColor =
            .label

        textField.adjustsFontForContentSizeCategory =
            true

        textField.delegate =
            context.coordinator

        textField.addTarget(
            context.coordinator,
            action:
                #selector(
                    Coordinator.textChanged(
                        _:
                    )
                ),
            for:
                .editingChanged
        )

        context.coordinator.textField =
            textField

        textField.inputAccessoryView =
            context.coordinator
                .makeAccessoryToolbar()

        return textField
    }


    func updateUIView(
        _ uiView:
            UITextField,
        context:
            Context
    ) {

        if uiView.text !=
            text {

            uiView.text =
                text
        }

        uiView.placeholder =
            placeholder

        uiView.font =
            font

        uiView.textAlignment =
            alignment
    }


    final class Coordinator:
        NSObject,
        UITextFieldDelegate {

        @Binding
        private var text:
            String

        weak var textField:
            UITextField?


        init(
            text:
                Binding<String>
        ) {

            _text =
                text
        }


        @objc
        func textChanged(
            _ sender:
                UITextField
        ) {

            text =
                sender.text ?? ""
        }


        func makeAccessoryToolbar()
            -> UIToolbar {

            let toolbar =
                UIToolbar()

            toolbar.sizeToFit()

            let spacer =
                UIBarButtonItem(
                    barButtonSystemItem:
                        .flexibleSpace,
                    target:
                        nil,
                    action:
                        nil
                )

            let done =
                UIBarButtonItem(
                    title:
                        "完成",
                    style:
                        .done,
                    target:
                        self,
                    action:
                        #selector(
                            doneTapped
                        )
                )

            toolbar.items =
                [
                    spacer,
                    done
                ]

            return toolbar
        }


        @objc
        private func doneTapped() {

            textField?
                .resignFirstResponder()
        }
    }
}
