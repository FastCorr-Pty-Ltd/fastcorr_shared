# FastCorr Shared Package

This package contains shared models and services for FastCorr applications, enabling unified communication between the `fastcorr_user` and `fastcorr_admin` apps.

## 🎯 Purpose

The FastCorr Shared Package provides:
- **Unified Communication Models**: Consistent message structures across apps
- **Cross-App Communication Service**: Real-time messaging between user and admin apps
- **System Logging**: Automatic logging of case events and status changes
- **Document Sharing**: Seamless file sharing between apps

## 📦 Contents

### Models
- `UnifiedCaseMessage`: Core message model for case communications
- `DocumentAttachment`: File attachment model
- `UnifiedMessageType`: Message type enumeration
- `UnifiedParticipantRole`: User role enumeration
- `MessageStatus`: Message status enumeration

### Services
- `UnifiedCaseCommunicationService`: Main service for managing case communications

## 🚀 Usage

### Adding to Your App

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  fastcorr_shared:
    path: ../fastcorr_shared  # Local path
    # or
    git:
      url: https://github.com/your-org/fastcorr_shared.git
      ref: main
```

### Basic Usage

```dart
import 'package:fastcorr_shared/fastcorr_shared.dart';

// Initialize the service
final commService = UnifiedCaseCommunicationService();

// Send a chat message
await commService.sendChatMessage(
  caseId: 'case_123',
  orgId: 'org_456',
  senderId: 'user_789',
  senderName: 'John Doe',
  senderRole: UnifiedParticipantRole.lawyer,
  content: 'Hello, I need an update on this case.',
);

// Listen to messages
commService.getCaseMessagesStream('org_456', 'case_123')
    .listen((messages) {
  // Handle incoming messages
  print('Received ${messages.length} messages');
});

// Create a system log
await commService.createSystemLog(
  caseId: 'case_123',
  orgId: 'org_456',
  content: 'Task status updated to: In Progress',
  metadata: {
    'action': 'status_update',
    'orderId': 'order_123',
    'status': 'inProgress',
  },
);
```

## 🏗️ Architecture

### Database Structure

```
organisations/{orgId}/cases/{caseId}/communications/{messageId}
├── id: "msg_123"
├── caseId: "case_456"
├── orgId: "org_789"
├── type: "chatMessage" | "systemLog" | "document" | "systemNotification"
├── senderId: "lawyer_001" | "secretary_002"
├── senderName: "John Smith" | "Sarah Johnson"
├── senderRole: "lawyer" | "secretary" | "admin" | "client"
├── content: "Hello, I need an update on this case"
├── attachments: [...]
├── timestamp: "2024-01-15T10:30:00Z"
├── status: "sent" | "delivered" | "read"
├── readBy: ["lawyer_001", "secretary_002"]
├── replyToMessageId: "msg_122" (optional)
└── metadata: {...}
```

### Message Types

1. **Chat Message**: Regular text communication between users
2. **System Log**: Automatic logging of case events and status changes
3. **Document**: File attachments and document sharing
4. **System Notification**: Important system announcements

### Participant Roles

- **Lawyer**: Legal counsel representing clients
- **Client**: Case client or party
- **Admin**: System administrator
- **Secretary**: Administrative staff handling cases
- **Driver**: Delivery and courier services
- **Court Clerk**: Court administrative staff
- **Observer**: Read-only access to communications

## 🔄 Integration with Apps

### User App (fastcorr_user)
- Lawyers send messages and upload documents
- Receive real-time updates from secretaries
- View system logs for case progress

### Admin App (fastcorr_admin)
- Secretaries respond to lawyer messages
- Create system logs for task updates
- Manage case communications

## 📱 Real-time Features

- **Live Messaging**: Messages appear instantly in both apps
- **Read Receipts**: Track who has read messages
- **System Logs**: Automatic logging of case events
- **Document Sharing**: Upload and download files
- **Search**: Find messages by content or sender

## 🛠️ Development

### Prerequisites
- Flutter SDK 3.9.0+
- Firebase project with Firestore and Storage enabled

### Dependencies
- `cloud_firestore`: ^5.6.12
- `firebase_core`: ^3.15.2
- `firebase_storage`: ^12.4.5
- `stacked`: ^3.0.0
- `uuid`: ^4.2.1

### Testing
```bash
flutter test
```

### Building
```bash
flutter pub get
flutter analyze
```

## 📝 Version History

### v1.0.0
- Initial release
- Unified case communication models
- Cross-app communication service
- System logging capabilities
- Document sharing support

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

---

**FastCorr Shared Package** - Enabling seamless communication across FastCorr applications.